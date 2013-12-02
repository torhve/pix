db = require "lapis.db"
redis = require "resty.redis"
config = require("lapis.config").get!
json = require "cjson"
os = require "os"

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



class Redis
  new: =>
    math.randomseed os.time!
    @prefix = config.redis_prefix
    @queuekey = @prefix .. ':upload:queue'
    @red = redis\new!
    ok, err = @red\connect unpack(config.redis)

  queue: (token) =>
    @red\lpush @queuekey, token

  queue_length: =>
    @red\llen @queuekey

class Sessions extends Model
  @timestamp: true
  @create: (email) =>


class Users extends Model
  @timestamp: true

  @create: (email) =>
    if @check_unique_constraint "email", email
      return nil, "Email already taken"

    token = generate_token 6
    while @check_unique_constraint "token", token
        token = generate_token 6

    name = ""

    Model.create @, {
      :email, :token, :name
    }

  @login: =>
    nil
  @logout: =>
    nil

  @read_session: (r) =>
    if r.session.user
      user = @find email: r.session.user.email
      unless user
        user = @create r.session.user.email
      user

  @write_session: (r, verification_data) =>
    r.session.user = {
      email: verification_data.email
      id: @id
    }

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
    super!

    -- Delete all images in album
    images = Images\select album_id:@id
    for image in *images
      image\delete!

    -- Delete folder
    execute 'rmdir ' .. table.concat { config.diskimgpath, @user_id, @id }, '/'

class Images extends Model
  @timestamp: true

  file_path: =>
    path = {
      config.imgpath,
      @user_id,
      @album_id,
      @id
    }
    table.concat path, '/'

  real_file_path: =>
    path = {
      config.diskimgpath,
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

  @create: (user_id, album_id, file_name) =>
    token = generate_token 6
    while @check_unique_constraint "token", token
        token = generate_token 6


    image = Model.create @, {
      :user_id, :token, :album_id, file_name:secure_filename(file_name), title:file_name, thumb_name:'', huge_name:''
    }
    execute "mkdir -p "..image\real_file_path!
    image

  delete: =>
    -- Remove file from filesystem
    execute "rm " .. @real_file_path! .. '/' .. @file_name
    execute "rm " .. @real_file_path! .. '/' .. @huge_name
    execute "rm " .. @real_file_path! .. '/' .. @thumb_name
    execute "rmdir " .. @real_file_path!

    super!



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

{ :Redis, :Users, :Albums, :Images, :Sessions, :Accesstokens, :generate_token }
