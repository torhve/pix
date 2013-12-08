lapis = require "lapis"
json = require "cjson"
import capture_errors from require "lapis.application"
import json_params, respond_to, capture_errors, capture_errors_json, assert_error, yield_error from require "lapis.application"
import validate, assert_valid from require "lapis.validate"
import escape_pattern, trim_filter, to_json from require "lapis.util"
db = require "lapis.db"
import Redis, Users, Albums, Images, Accesstokens, generate_token, imagedatesql from require "photongx.models"
config = require("lapis.config").get!

require_login = (fn) ->
  =>
    if @current_user
      fn @
    else
      redirect_to: @url_for "admin"

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
  layout: require "photongx.views.layout"
  views_prefix: "photongx.views"

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
      images = Images\get_coverimage album.id
      album.image = images[1]
      album.url = @url_for("album", token:album.token, title:album.title)
    render: true

  [tokenalbums: "/albums/:slug/"]: capture_errors =>
    @accesstokens = Accesstokens\for_slug @params.slug
    unless #@accesstokens > 0
      return render: "error", status: 404
    album_ids = [a.album_id for a in *@accesstokens]
    @albums = Albums\find_all album_ids

    -- FIXME improve SQL to single statement
    for album in *@albums
      images = Images\get_coverimage album.id
      album.image = images[1]
      -- Override the token with our given slug so the template generates the correct URLs
      album.slug = @params.slug
      album.url = @url_for("tokenalbum", slug:@params.slug, token:album.token, title:album.title)
    render: "albums"

  [album: "/album/:token/:title/"]: =>
    if @current_user
      @album = Albums\find token:@params.token
      unless @album
        return render:"error", status:404
      unless @current_user.id == @album.user_id
        return render:"error", status:403
    unless @album return render:"error", status:403
    @album.views = @album.views + 1
    @album\update "views"
    @images = Images\select "where album_id = ? ORDER BY date, file_name", @album.id, fields: "*, "..imagedatesql
    @albumurl = @url_for('album', token:@params.token, title:@album.title)
    @albumsurl = @url_for('albums')
    render: true

  [tokenalbum: "/album/:slug/:token/:title/"]: =>
    @album = Albums\find token:@params.token
    unless @album
      return render:"error", status:404
    valid_token = Accesstokens\validate_album @params.slug, @album.id
    unless valid_token
      return render:"error", status:410
    @albumurl = @url_for('tokenalbum', slug:@params.slug, token:@album.token, title:@album.title)
    @albumsurl = @url_for('tokenalbums', slug:@params.slug)
    @album.views = @album.views + 1
    @album\update "views"
    @images = Images\select "where album_id = ? ORDER BY date, file_name", @album.id, fields: "*, "..imagedatesql
    render: "album"


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

    POST: capture_errors_json require_login json_params =>

      assert_valid @params, {
        { "name", exists: true, min_length: 1 }
      }
      -- Get or create
      album = Albums\find user_id: @current_user.id, title:@params.name
      unless album
        album = Albums\create @current_user.id, @params.name
      json: { album: album }
  }

  "/api/albums/:album_id": respond_to {
    PUT: capture_errors_json require_login json_params =>
      album = Albums\find id:@params.album_id, user_id: @current_user.id
      album.title = @params.title
      album\update "title"
      json: {:album}
    DELETE: capture_errors_json require_login =>
      album = Albums\find id:@params.album_id, user_id: @current_user.id
      unless album
        return render:"error", status:404
      album\delete!
      json:album
  }

  "/api/images/:album_id": respond_to {

    GET: capture_errors_json require_login =>
      album = Albums\find id:@params.album_id
      unless album
        return render:"error", status:404
      unless album.user_id == @current_user.id
        return render:"error", status:403
      images = assert_error Images\select "where album_id = ? ORDER BY date", @params.album_id, fields: "*, "..imagedatesql
      --- TODO maybe use raw query to cast hstore to json?
      -- Examples found:https://gist.github.com/WoLpH/2318757
      -- Or use postgresql 9.3 which can cast hstore to JSON
      for image in *images
        if image.metadata
          newstr, n, err = ngx.re.gsub(image.metadata, "=>", ":")
          image.metadata = json.decode '{'..newstr..'}'
      json: {:images}
  }

  "/api/accesstokens/:album_id": respond_to {

    GET: capture_errors_json require_login =>
      accesstokens = Accesstokens\select "where user_id = ? and album_id = ?", @current_user.id, @params.album_id
      json: {:accesstokens}

    DELETE: =>
      accesstoken = Accesstokens\find id:@params.album_id, user_id:@current_user.id
      unless accesstoken
        return render:"error", status:404
      accesstoken\delete!
      json:{ :accesstoken }
  }


  [images: "/api/images"]: respond_to {
    GET:capture_errors_json require_login  =>
      images = assert_error Images\select "where user_id = ?", @current_user.id
      json: {:images}

    POST: capture_errors_json require_login =>
        assert_valid @params, {
            {'upload', file_exists: true}
            {'filename', exists: true}
            {'title', exists: true}
            {'token', exists: true}
            {'checksum', exists: true}
        }
        {:upload, :title, :filename, :token, :checksum} = @params
        pattern = '\\.(jpe?g|gif|png|crw|raw)$'
        unless ngx.re.match(filename, pattern, "i") 
            return json:status:403, error:'Filename must be of image type'
        file = @params.upload
        album = assert_error Albums\find user_id: @current_user.id, token:token
        success, image = pcall -> Images\create @current_user.id, album.id, filename
        -- Since there is a likely chance our silly token can be duplicate we just try to generate image again if it fails
        while not success
          success, image = pcall -> Images\create @current_user.id, album.id, filename
        content = file.content
        real_file_name = image\real_file_name!
        diskfile = io.open real_file_name, 'w'
        unless diskfile
          -- TODO delete created image from SQL
          return status:403, json:{status:403, error:"Permission denied"} 
        diskfile\write file.content
        diskfile\flush!
        diskfile\close
        redis = Redis!
        queue = assert_error redis\queue image.token
        json: 'success'
  }

  [photostreamimages: "/api/photostreamimages"]: respond_to {
    GET:capture_errors_json require_login  =>
      photostreamimages = assert_error Images\select "WHERE user_id = ? ORDER BY date DESC", @current_user.id, fields: "*, "..imagedatesql
      json: {:photostreamimages}
    }

  "/api/albumttl/:album_id": respond_to {
    POST: capture_errors_json require_login =>
      assert_valid @params, {
        { "name", exists: true}
        { "ttl", exists: true}
      }
      ttl = tonumber @params.ttl
      -- TTL not a number ? Assume forever.
      if ttl == nil
          ttl = 2^32 -- ~150 years

      name = @params.name
      album = Albums\find id:@params.album_id, user_id: @current_user.id
      accesstoken = Accesstokens\create @current_user.id, album.id, name, ttl

      json: {:album,:accesstoken}
    }

  [admin: "/admin/"]: =>
    layout:'admin' 

  "/api/tag": =>
    json: {token: generate_token 6}

  "/api/image/:image_id": respond_to {
    DELETE: capture_errors_json require_login =>
      image = Images\find id:@params.image_id, user_id: @current_user.id
      unless image
        return render:"error", status:"404"
      image\delete!
      json:image
  }

  "/api/img/click": =>
    assert_valid @params, {
      { "img", exists: true, min_length: 6 }
    }
    @image = Images\find token:@params.img
    unless @image
      return render: "error", status: 404
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


  "/db/make": require_login =>
    -- Hard coded to first user for now
    if @current_user.id == 1 
      schema = require "schema"
      schema.make_schema!
      return json: { status: "ok" }
    json: status: 403

  "/db/destroy": require_login =>
    -- Hard coded to first user for now
    if @current_user.id == 1 
      schema = require "schema"
      schema.destroy_schema!
      return json: { status: "ok" }
    json: status: 403

  "/db/migrate": require_login =>
    -- Hard coded to first user for now
    if @current_user.id == 1 
      import run_migrations from require "lapis.db.migrations"
      run_migrations require "migrations"
      return json: { status: "ok" }
    json: status: 403

  "/debug": =>
    status, user = pcall -> Users\find id: "faf"
    "result: #{user.id}, status: #{status}"
