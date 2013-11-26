lapis = require "lapis"
json = require "cjson"
import capture_errors from require "lapis.application"
import respond_to, capture_errors, capture_errors_json, assert_error, yield_error from require "lapis.application"
import validate, assert_valid from require "lapis.validate"
import escape_pattern, trim_filter from require "lapis.util"
import Users, Albums, Images, generate_token from require "models"
config = require("lapis.config").get!

--models.init!

require_login = (fn) ->
  =>
    if @current_user
      fn @
    else
      redirect_to: @url_for "user_login"

json_params = (fn) ->
  =>
    body = ngx.req.get_body_data!
    if body
      @json_params = json.decode body
      fn @
    else
      json:{error:"No parameters recieved"}

persona_verify = (assertion, audience) -> 

    options = { method:ngx.HTTP_POST, body:json.encode {:assertion, :audience} }
    res, err = ngx.location.capture('/persona/', options)

    if not res then
      return { err: res }

    if res.status >= 200 and res.status < 300 then
        return json.decode(res.body)
    else
        return {
            status:res.status,
            body:res.body
        }

class extends lapis.Application
  layout: require "views.layout"

  @before_filter =>
    @current_user = Users\read_session @

  [index: "/"]: =>
    "Welcome to Lapis #{require "lapis.version"}!"

  [user_login: "/api/persona/login"]: respond_to {
    POST: capture_errors_json =>
      body = ngx.req.get_body_data!
      if body
        body = json.decode body

        verification_data = persona_verify body.assertion, config.site
        if verification_data.status == 'okay' 
          Users\write_session @, verification_data
          json:verification_data
      json: {email:false}
  }
  [persona_status: "/api/persona/status"]: respond_to {
    GET: =>
      render: true

    POST: capture_errors_json =>
      cu = @current_user
      if cu 
        return json:{email:cu.email}
      json:{email:false}
  }
  [user_logout: "/api/persona/logout"]: =>
    @session.user = false
    json: {email:false}

-- ALBUMS API view - get albums or add new album
  [albums: "/api/albums"]: respond_to {
    GET: =>
      json: 'todo'

    POST: capture_errors_json json_params =>

      assert_valid @json_params, {
        { "name", exists: true, min_length: 1 }
      }
      -- Get or create
      album = Albums\find user_id: @current_user.id, title:@json_params.name
      unless album
        album = Albums\create @current_user.id, @json_params.name
      json: { album: album }
  }


  [images: "/api/images"]: respond_to {
    GET: =>
      json: "todo"

    POST: capture_errors_json =>
        assert_valid @params, {
            {'upload', file_exists: true}
        }
        -- XXX assert_valid ?
        h = @req.headers
        fmd5       = h['X-Checksum'] 
        file_name  = h['X-Filename']
        referer    = h['referer']
        album      = h['X-Album']
        tag        = h['X-Tag']
        file = @params.upload
        album = Albums\find user_id: @current_user.id, title:album
        ngx.log ngx.ERR, json.encode album
        image = Images\create @current_user.id, album.id, file_name
        content = file.content
        real_file_name = image\real_file_name!
        diskfile = io.open real_file_name, 'w+'
        diskfile\write file.content
        diskfile\close
        json: 'success'
  }

  [admin: "/admin/"]: =>
    layout:'admin' 

  "/api/tag": =>
    json: {token: generate_token 6}

  [adminapi: "/admin/api/all"]: =>
    ok = "test"
    json: { status: ok}

  "/admin/db/make": =>
    schema = require "schema"
    schema.make_schema!
    json: { status: "ok" }

  "/admin/db/destroy": =>
    schema = require "schema"
    schema.destroy_schema!
    json: { status: "ok" }

  "/admin/db/migrate": =>
    import run_migrations from require "lapis.db.migrations"
    run_migrations require "migrations"
    json: { status: "ok" }

  "/admin/user/create": =>
    assert_valid @params, {
      { "email", exists: true, min_length: 3 }
    }
    user = models.Users\create @params.email
    json: { user: user }
