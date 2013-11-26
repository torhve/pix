db = require "lapis.db"
redis = require "resty.redis"
config = require("lapis.config").get!

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
    }

class Albums extends Model
  @timestamp: true

  @create: (email, title) =>
    token = generate_token 6
    while @check_unique_constraint "token", token
        token = generate_token 6

    Model.create @, {
      :user_id, :token, :title
    }

class Images extends Model
  @timestamp: true

  @create: (album, email, title) =>
    token = generate_token 6
    while @check_unique_constraint "token", token
        token = generate_token 6

    Model.create @, {
      :user_id, :token, :title
    }

{ :R, :init, :Users, :Albums, :Images, :Sessions, generate_token }
