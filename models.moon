db = require "lapis.db"
redis = require "resty.redis"
config = require("lapis.config").get!
json = require "cjson"

import execute from require "os"

import Model from require "lapis.db.model"
import underscore, slugify from require "lapis.util"

math.randomseed os.time!
R = nil

init = ->
  -- Put redis init in a function or else we get cannot yield across C boundary since we can't init a connection in a require function
  R = redis\new!
  ok, err = R\connect unpack(config.redis)

local *


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
      if user
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

  real_file_name: =>
    @file_path! .. '/' .. @file_name

  @create: (user_id, album_id, file_name) =>
    token = generate_token 6
    while @check_unique_constraint "token", token
        token = generate_token 6


    image = Model.create @, {
      :user_id, :token, :album_id, file_name:secure_filename(file_name), title:file_name, thumb_name:'', huge_name:''
    }
    execute "mkdir -p "..image\file_path!
    image

{ :R, :init, :Users, :Albums, :Images, :Sessions, :generate_token }
