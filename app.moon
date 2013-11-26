lapis = require "lapis"
json = require "cjson"
import capture_errors from require "lapis.application"
import respond_to, capture_errors, capture_errors_json, assert_error, yield_error from require "lapis.application"
import validate, assert_valid from require "lapis.validate"
import escape_pattern, trim_filter from require "lapis.util"
import Users, Albums, Images from require "models"
config = require("lapis.config").get!

--models.init!

require_login = (fn) ->
  =>
    if @current_user
      fn @
    else
      redirect_to: @url_for "user_login"

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
    GET: =>
      render: true

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
      json:{email:@current_user.email}
  }

-- ALBUMS API view - get albums or add new album
  [albums: "/api/albums"]: respond_to {
    GET: =>
      json: 'todo'

    POST: capture_errors_json =>

      assert_valid @params, {
        { "name", exists: true, min_length: 1 }
      }
      album = models.Album\create @params.email
      json: { album: album }
  }


  [upload: "/upload"]: respond_to {
    before: =>
      @title = "Upload"

    GET: =>
      render: true

    POST: capture_errors =>
        csrf.assert_token @
        assert_valid @params, {
            {'upload', file_exists: true}
        }
        file = @params.upload
        content = file.content
        timestamp = ngx.now!
        filename = secure_filename file.filename
        fileurl = 'static/uploads/'..timestamp..'_'..filename
        diskfile = io.open fileurl, 'w'
        diskfile\write file.content
        diskfile\close

        {:type, :CKEditorFuncNum } = @params
        message = '' -- XXX add lots of error checking
        url = '/' .. fileurl

        res = "<script type='text/javascript'>window.parent.CKEDITOR.tools.callFunction(#{CKEditorFuncNum}, '#{url}', '#{message}');</script>"
        @write res
  }

  [admin: "/admin/"]: =>
    layout:'admin' 

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
