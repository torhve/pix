db = require "lapis.db"
redis = require "resty.redis"
bcrypt = require 'bcrypt'
config = require("lapis.config").get!
os = require "os"
import assert_error from require "lapis.application"
import from_json, to_json from require "lapis.util"

import execute from require "os"

import Model from require "lapis.db.model"
import underscore, slugify from require "lapis.util"


local *

format_date = (time) ->
    os.date "!%Y-%m-%d %H:%M:%S", time

generate_token = do
  import random from math
  random_char = ->
    switch random 1,3
      when 1
        random 65, 90
      when 2
        random 97, 122
      when 3
        random 48, 57

  (length) ->
    string.char unpack [ random_char! for i=1,length ]

secure_filename = (str) ->
    (str\gsub("%s+", "-")\gsub("%.+", ".")\gsub("[^%w%-_%.]+", ""))

imagedatesql = do
  [[
        date_part('epoch',
          COALESCE(
            to_timestamp(metadata->'DateTimeOriginal', 'YYYY:MM:DD HH24:MI:SS'),
            to_timestamp(metadata->'CreateDate', 'YYYY:MM:DD HH24:MI:SS'),
            created_at
          ))*1000 AS date
  ]]

cache_session = (session) ->
  session_cache = ngx.shared.session_cache
  if session.email and session.id
    session_cache\set(session.email, to_json(session))

class Redis
  new: =>
    math.randomseed os.time!
    @prefix = config.redis.prefix
    @queuekey = @prefix .. ':upload:queue'
    @red = redis\new!
    @red\connect config.redis.host, config.redis.port

  queue: (token) =>
    @red\lpush @queuekey, token

  queue_length: =>
    @red\llen @queuekey

class Sessions extends Model
  @timestamp: true
  @create: (email) =>

-- Generate a hash with a 2^12 cost
generate_hash = (s) ->
  bcrypt.digest(s, 12)

class Users extends Model
  @timestamp: true

  @create: (email, password) =>
    if @check_unique_constraint "email", email
      return nil, "Email already taken"

    token = generate_token 6
    while @check_unique_constraint "token", token
        token = generate_token 6

    name = ""

    encrypted_password = generate_hash email .. password .. config.bcrypt_token

    Model.create @, {
      :email, :token, :name, :encrypted_password
    }

  @login: (username, password) =>
    user = @find email: username
    -- No user found with that username
    if not user
        return false, "err_invalid_user"
    verified = bcrypt.verify(username .. password .. config.bcrypt_token, user.encrypted_password)
    if verified
      return true, user
    return false, "err_invalid_user"
  @logout: =>
    nil

  @read_session: (r) =>
    if r.session.user
      -- First check session cache for user
      session_cache = ngx.shared.session_cache
      user = session_cache\get r.session.user.email
      if user
        return from_json user
      -- No cache hit, try database
      user = @find email: r.session.user.email
      -- No database hit, create a new user
      unless user
        user = @create r.session.user.email
      -- Write session to cache
      cache_session(user)
      user

  @write_session: (r, verification_data) =>
    session = {
      email: verification_data.email
    }
    -- Write the cookie
    r.session.user = session

class Albums extends Model
  @timestamp: true

  @create: (user_id, title) =>
    token = generate_token 6
    while @check_unique_constraint "token", token
        token = generate_token 6

    Model.create @, {
      :user_id, :token, :title
    }

  delete: =>

    -- Delete all images in album
    unless @id
      return nil, "Error: no id"
    images = Images\select "where album_id = ?", @id
    for image in *images
      image\delete!

    -- Delete folder
    execute 'rmdir ' .. table.concat { config.path.disk, @user_id, @id }, '/'

    super!

class Images extends Model
  @timestamp: true

  file_path: =>
    path = {
      config.path.image,
      @user_id,
      @album_id,
      @id
    }
    table.concat path, '/'

  real_file_path: =>
    path = {
      config.path.disk,
      @user_id,
      @album_id,
      @id
    }
    table.concat path, '/'

  get_url: =>
    '/'..@real_file_name!

  get_real_thumb_url: =>
    if @thumb_name
      '/'..@file_path!..'/'..@thumb_name
    else
      '/'..@real_file_name!

  get_real_huge_url: =>
    if @huge_name
      '/'..@file_path!..'/'..@huge_name
    else
      '/'..@real_file_name!


  get_huge_url: =>
    --XXX url_for ? config?
    unless @huge_name == ''
      '/img/'..@token..'/'..@huge_name
    else
      '/img/'..@token..'/'..@file_name

  get_thumb_url: =>
    --XXX url_for ? config?
    unless @thumb_name == ''
      '/img/'..@token..'/'..@thumb_name
    else
      '/img/'..@token..'/'..@file_name



  real_file_name: =>
    @real_file_path! .. '/' .. @file_name

  get_file_size: =>
      fp = io.open @real_file_name!
      if fp == nil then
        return 0
      filesize = fp\seek "end"
      fp\close()
      return filesize


  @create: (user_id, album_id, file_name) =>
    token = generate_token 6
    while @check_unique_constraint "token", token
        token = generate_token 6


    image = assert_error Model.create @, {
      :user_id, :token, :album_id, file_name:secure_filename(file_name), title:file_name, thumb_name:'', huge_name:''
    }
    if image
      execute "mkdir -p "..image\real_file_path!
    image

  delete: =>
    -- Remove file from filesystem
    execute "rm " .. @real_file_path! .. '/' .. @file_name
    execute "rm " .. @real_file_path! .. '/' .. @huge_name
    execute "rm " .. @real_file_path! .. '/' .. @thumb_name
    execute "rmdir " .. @real_file_path!

    super!

  get_coverimage: (album_id) =>
    Images\select "where album_id = ? order by views desc limit 1", album_id

  get_coverimages: (albums) =>
    flat_ids = table.concat [db.escape_literal a.id for a in *albums], ", "
    Images\select "where album_id IN ("..flat_ids..") order by album_id DESC, views DESC", flat_ids, fields:"distinct on (album_id) *"


class Accesstokens extends Model
  @timestamp: true

  @create: (user_id, album_id, name, expires_in) =>
    slug = slugify name
    expires_at = format_date ngx.now! + expires_in
    accesstoken = Model.create @, {
      :user_id, :album_id, :slug, :expires_at
    }
    accesstoken

  @for_slug: (slug) =>
    db.select "* from accesstokens where slug = ? and now() < expires_at", slug

  @validate_album: (slug, album_id) =>
    res = db.select "* from accesstokens where slug = ? and album_id = ? and now() < expires_at", slug, album_id
    if #res > 0
      db.update "accesstokens", {
        views: db.raw"views + 1"
        }, {
          album_id:album_id,
          slug:slug
        }
      return true
    else
      return false

{ :Redis, :Users, :Albums, :Images, :Sessions, :Accesstokens, :generate_token, :imagedatesql }
