lapis = require "lapis"
json = require "cjson"
import capture_errors from require "lapis.application"
import respond_to, capture_errors, capture_errors_json, assert_error, yield_error from require "lapis.application"
import validate, assert_valid from require "lapis.validate"
import escape_pattern, trim_filter from require "lapis.util"
import Redis, Users, Albums, Images, generate_token from require "models"
config = require("lapis.config").get!

--models.init!

require_login = (fn) ->
  =>
    if @current_user
      fn @
    else
      redirect_to: @url_for "admin"

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
    if @current_user
      return redirect_to: @url_for "albums"
    render:true

  [albums: "/albums"]: require_login =>
    @albums = Albums\select "where user_id = ?", @current_user.id
    -- FIXME improve SQL to single statement
    for album in *@albums
      images = Images\select "where album_id = ? order by views desc limit 1", album.id
      album.image = images[1]
    render: true

  [album: "/album/:token/:title/"]: require_login =>
    @album = assert_error Albums\find token:@params.token
    @album.views = @album.views + 1
    @album\update "views"
    @images = Images\select "where album_id = ?", @album.id
    render: true

--
-- This view gets called from a rewrite_by_lua handler so it exits
-- because: "Note that when calling ngx.exit(ngx.OK) within a rewrite_by_lua handler, the nginx request processing control flow will still continue to the content handler."
--
  [img: "/img/:token/:filename"]: =>

    -- Check if user has permission to see image or return 403
    -- Check if token is valid
    -- Set real url or return 404

    -- Simple auth check for now
    --unless @current_user
    --  ngx.exit(403)
    
    -- TODO maybe disallow original?

    @image = Images\find token:@params.token
    unless @image
      ngx.exit(404)

    -- Check access tokens and return status 410 if expired
    imguri = '/real' .. @image\file_path! .. '/' ..@params.filename
    ngx.req.set_uri imguri, true

  [persona_login: "/api/persona/login"]: respond_to {
    POST: capture_errors_json =>
      body = ngx.req.get_body_data!
      if body
        body = json.decode body

        verification_data = persona_verify body.assertion, config.site
        if verification_data.status == 'okay' 
          Users\write_session @, verification_data
          return json:verification_data
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
  [apialbums: "/api/albums"]: respond_to {
    GET: capture_errors_json require_login =>
      albums = assert_error Albums\select "where user_id = ?", @current_user.id
      json: {:albums}

    POST: capture_errors_json json_params require_login =>

      assert_valid @json_params, {
        { "name", exists: true, min_length: 1 }
      }
      -- Get or create
      album = Albums\find user_id: @current_user.id, title:@json_params.name
      unless album
        album = Albums\create @current_user.id, @json_params.name
      json: { album: album }
  }


  "/api/images/:album_id": capture_errors_json require_login =>
    images = assert_error Images\select "where user_id = ? and album_id = ?", @current_user.id, @params.album_id
    json: {:images}

  [images: "/api/images"]: respond_to {
    GET:capture_errors_json require_login  =>
      images = assert_error Images\select "where user_id = ?", @current_user.id
      json: {:images}

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
        pattern = '\\.(jpe?g|gif|png)$'
        unless ngx.re.match(file_name, pattern, "i") 
            return json:status:403, error:'Filename must be of image type'
        file = @params.upload
        album = assert_error Albums\find user_id: @current_user.id, title:album
        image = assert_error Images\create @current_user.id, album.id, file_name
        content = file.content
        real_file_name = image\real_file_name!
        diskfile = io.open real_file_name, 'w+'
        diskfile\write file.content
        diskfile\close
        redis = Redis!
        queue = assert_error redis\queue image.token
        json: 'success'
  }

  [admin: "/admin/"]: =>
    layout:'admin' 

  "/api/tag": =>
    json: {token: generate_token 6}

  "/api/img/click": =>
    assert_valid @params, {
      { "img", exists: true, min_length: 6 }
    }
    @image = Images\find token:@params.img
    unless @image
      ngx.exit(404)
    @image.views = @image.views + 1
    @image\update "views"

    json: {views: @image.views}

  [adminapi: "/admin/api/all"]: =>
    ok = "test"
    json: { status: ok}
   
  "/api/queue": require_login capture_errors_json =>
    redis = Redis!
    queue = assert_error redis\queue_length!
    json: {counter:queue}


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

