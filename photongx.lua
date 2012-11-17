-- use nginx $root variable for template dir
local TEMPLATEDIR = ngx.var.root .. '/';
local cjson = require("cjson")
local math  = require("math")

-- Load redis
local redis = require "resty.redis"

-- Set the content type
ngx.header.content_type = 'text/html';

-- the db global
red = nil
BASE = '/'
IMGPATH = '/home/xt/src/photongx/img/'
TAGLENGTH = 6

-- Default context helper
function ctx(ctx)
    ctx['BASE'] = BASE
    ctx['IMGBASE'] = ngx.var.imgbase
    return ctx
end

-- Template helper
function escape(s)
    if s == nil then return '' end

    local esc, i = s:gsub('&', '&amp;'):gsub('<', '&lt;'):gsub('>', '&gt;')
    return esc
end

-- Helper function that loads a file into ram.
function load_file(name)
    local intmp = assert(io.open(name, 'r'))
    local content = intmp:read('*a')
    intmp:close()

    return content
end

-- Used in template parsing to figure out what each {} does.
local VIEW_ACTIONS = {
    ['{%'] = function(code)
        return code
    end,

    ['{{'] = function(code)
        return ('_result[#_result+1] = %s'):format(code)
    end,

    ['{('] = function(code)
        return ([[ 
            if not _children[%s] then
                _children[%s] = tload(%s)
            end

            _result[#_result+1] = _children[%s](getfenv())
        ]]):format(code, code, code, code)
    end,

    ['{<'] = function(code)
        return ('_result[#_result+1] =  escape(%s)'):format(code)
    end,
}

-- Takes a view template and optional name (usually a file) and 
-- returns a function you can call with a table to render the view.
function compile_view(tmpl, name)
    local tmpl = tmpl .. '{}'
    local code = {'local _result, _children = {}, {}\n'}

    for text, block in string.gmatch(tmpl, "([^{]-)(%b{})") do
        local act = VIEW_ACTIONS[block:sub(1,2)]
        local output = text

        if act then
            code[#code+1] =  '_result[#_result+1] = [[' .. text .. ']]'
            code[#code+1] = act(block:sub(3,-3))
        elseif #block > 2 then
            code[#code+1] = '_result[#_result+1] = [[' .. text .. block .. ']]'
        else
            code[#code+1] =  '_result[#_result+1] = [[' .. text .. ']]'
        end
    end

    code[#code+1] = 'return table.concat(_result)'

    code = table.concat(code, '\n')
    local func, err = loadstring(code, name)

    if err then
        assert(func, err)
    end

    return function(context)
        assert(context, "You must always pass in a table for context.")
        setmetatable(context, {__index=_G})
        setfenv(func, context)
        return func()
    end
end

function tload(name)

    name = TEMPLATEDIR .. name

    if not os.getenv('PROD') then
        local tempf = load_file(name)
        return compile_view(tempf, name)
    else
        return function (params)
            local tempf = load_file(name)
            assert(tempf, "Template " .. name .. " does not exist.")

            return compile_view(tempf, name)(params)
        end
    end
end




-- KEY SCHEME
-- albums            z: zalbums                    = set('albumname', 'albumname2', ... )
-- tags              h: albumnameh                 = 'tag'
-- album             z: albumname                  = set('itag/filename', 'itag2/filename2', ...)
-- images            h: itag/filename              = {album: 'albumname', timestamp: ... ... }
-- album image tags  s: album:albumname:imagetags  = ['asdf90', 'bsdf90', 'cabcdef', ...]
-- album access tags s: album:albumname:accesstags = ['bsdf88,  'asoid1', '198mxoi', ...]
-- album access tag  h: album:albumname:ebsdf88    = {granted: date, expires: date, accessed: counter}
--

-- Upload Queue
-- queue l: queue:thumb = [img, img, img, img]


-- URLs
-- /base/atag/albumname
-- /base/atag/itag/img01.jpg
-- /base/atag/itag/img01.fs.jpg
-- /base/atag/itag/img01.t.jpg




-- helpers

-- Get albums
function getalbums(accesskey) 
    local allalbums, err = red:zrange("zalbums", 0, -1)

    if err then
        ngx.say(err)
        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end

    local albums = {}
    if accesskey then
        for i, album in ipairs(allalbums) do
            if verify_access_key(accesskey, album) then
                table.insert(albums, album)
            end
        end
    else
        albums = allalbums
    end
    return albums
end

-- Function to transform a potienially unsecure filename to a secure one
function secure_filename(filename)
    filename = string.gsub(filename, '/', '')
    filename = string.gsub(filename, '%.%.', '')
    return filename
end

-- Function to generate a simple tag 
function generate_tag()
    ascii = 'abcdefgihjklmnopqrstuvxyz'
    digits = '1234567890'
    pool = ascii .. digits

    res = {}
    while #res < TAGLENGTH do
        local choice = math.floor(math.random()*#pool)+1
        table.insert(res, string.sub(pool, choice, choice))
    end
    res = table.concat(res, '')

    return res
end

-- Check if any given tag is up to snuff
function verify_tag(tag)
    if not tag then return false end
    if #tag < TAGLENGTH then return false end
    if not ngx.re.match(tag, '^[a-zA-Z0-9]+$') then return false end
    return true
end

function verify_access_key(key, album)
    local accesskey = 'album:' .. album .. ':' .. key
    local exists = red:exists(accesskey) == 1
    return exists
end


--
--
-- ******* VIEWS ******* 
--



-- 
-- Albums view
--
local function albums(match)
    local accesskey = match[1]
    local albums = getalbums(accesskey)

    local images = {}
    tags  = {}
    local imagecount = 0

    -- Fetch a cover img
    for i, album in ipairs(albums) do
        -- FIXME, only get 1 image
        local theimages, err = red:zrange(album, 0, -1)
        imagecount = imagecount + #theimages
        if err then
            ngx.say(err)
            return
        end
        local tag, err = red:hget(album .. 'h', 'tag')
        tags[album] = tag
        for i, image in ipairs(theimages) do
            images[album] = image
            break
        end
    end

    -- load template
    local page = tload('albums.html')
    local context = ctx{
        albums = albums, 
        imagecount = imagecount,
        images = images, 
        bodyclass = 'gallery'}
    -- render template with counter as context
    -- and return it to nginx
    ngx.print( page(context) )
end

-- 
-- About view
--
local function index()
    -- load template
    local page = tload('main.html')
    local context = ctx{
        bodyclass = 'gallery',
    }
    -- render template with counter as context
    -- and return it to nginx
    ngx.print( page(context) )
end

--
-- View for a single album
-- 
local function album()

    local path_vars = ngx.re.match(ngx.var.uri, '/(\\w+)/(\\d+)?/?$')
    local album = path_vars[1]
    local image_num = path_vars[2]
    local imagelist, err = red:zrange(album, 0, -1)
    local tag, err = red:hget(album .. 'h', 'tag')
    local thumbs = {}
    for i, image in ipairs(imagelist) do
        local itag = red:hget(image, 'itag')
        -- Get thumb if key exists
        -- set to full size if it doesn't exist
        if red:hexists(image, 'thumb_name') == 1 then
            thumbs[image] = itag .. '/' .. red:hget(image, 'thumb_name')
        else
            thumbs[image] = itag .. '/' .. red:hget(image, 'file_name')
        end
    end
    
    -- load template
    local page = tload('album.html')
    local context = ctx{ 
        album = album,
        tag = tag,
        imagelist = imagelist,
        thumbs = thumbs,
        bodyclass = 'gallery',
        showimage = image_num,
    }
    -- render template with counter as context
    -- and return it to nginx
    ngx.print( page(ctx(context)) )
end

local function upload()
    -- load template
    local page = tload('upload.html')
    local args = ngx.req.get_uri_args()

    -- generate tag to make guessing urls non-worky
    local tag = generate_tag()

    local context = ctx{album=args['album'], tag=tag}
    -- and return it to nginx
    ngx.print( page(context) )
end

--
-- Admin view
-- 
local function admin()
    local albums = getalbums()
    local tags  = {}
    local images = {}
    local thumbs = {}
    local imagecount = 0

    -- Fetch a cover img
    for i, album in ipairs(albums) do
        local theimages, err = red:zrange(album, 0, -1)
        local tag,       err = red:hget(album .. 'h', 'tag')
        tags[album] = tag
        images[album] = theimages
        imagecount = imagecount + #theimages
        thumbs[album] = {}
        for i, image in ipairs(theimages) do
            local itag = red:hget(image, 'itag')
            -- Get thumb if key exists
            -- set to full size if it doesn't exist
            if red:hexists(image, 'thumb_name') == 1 then
                thumbs[album][image] = itag .. '/' .. red:hget(image, 'thumb_name')
            else
                thumbs[album][image] = itag .. '/' .. red:hget(image, 'file_name')
            end
        end
    end

    -- load template
    local page = tload('admin.html')
    local args = ngx.req.get_uri_args()

    -- generate tag to make guessing urls non-worky
    local tag = generate_tag()

    local context = ctx{
        album=args['album'], 
        tag=tag,
        albums = albums,
        tags = tags,
        images = images,
        thumbs = thumbs,
        imagesjs = cjson.encode(images),
        albumsjs = cjson.encode(albums),
        tagsjs   = cjson.encode(tags),
        imagecount = imagecount,
    }
    -- and return it to nginx
    ngx.print( page(context) )
end



local function add_file_to_db(album, itag, h)
    local imgh       = {}
    local timestamp  = ngx.time() -- FIXME we could use header for this
    imgh['album']    = album
    imgh['atag']     = h['X-tag']
    imgh['itag']     = itag
    imgh['timestamp']= timestamp
    imgh['client']   = ngx.var.remote_addr
    imgh['file_name']= h['x-file-name'] -- FIXME escaping
    local albumskey  = 'zalbums' -- albumset
    local albumkey   =  album    -- image set
    local albumhkey  =  album .. 'h' -- album metadata
    local imagekey   =  imgh['itag'] .. '/' .. h['x-file-name']
    local itagkey    =  'album:' .. album .. ':imagetags'

    red:zadd(albumskey, timestamp, albumkey) -- add album to albumset
    red:zadd(albumkey , timestamp, imagekey) -- add imey to imageset
    red:sadd(itagkey, itag)                  -- add itag to set of used itags
    red:hmset(imagekey, imgh)                -- add imagehash
    -- only set tag if not exist
    red:hsetnx(albumhkey, 'tag', h['X-tag'])

    -- Add the uploaded image to the queue
    red:lpush('queue:thumb', imagekey)
end

--
-- View that recieves data from upload page
--
local function upload_post()

    -- Read body from nginx so file is available for consumption
    ngx.req.read_body()

    local h          = ngx.req.get_headers()
    local md5        = h['content-md5'] -- FIXME check this with ngx.md5
    local file_name  = h['x-file-name']
    local referer    = h['referer']
    local album      = h['X-Album']
    local tag        = h['X-Tag']
    local itag       = generate_tag()  -- Image tag

    -- None unsecure shall pass
    file_name = secure_filename(file_name)

    -- Tags needs to be checked too
    if not verify_tag(tag) then
        ngx.status = 403
        ngx.say('Invalid tag specified')
        return
    end

    -- Check if tag is OK
    local albumhkey =  album .. 'h' -- album metadata
    red:hsetnx(albumhkey, 'tag', h['X-tag'])
    -- FIXME verify correct tag
    local tag, err = red:hget(albumhkey, 'tag')

    local path  = IMGPATH

    -- FIXME Check if tag already in use
    -- simple trick to check if path exists
    local albumpath = path .. tag .. '/' .. album
    if not os.rename(path .. tag, path .. tag) then
        os.execute('mkdir -p ' .. path .. tag)
    end
    if not os.rename(albumpath, albumpath) then
        os.execute('mkdir -p ' .. albumpath)
    end

    -- Find unused tag if already in use
    while red:sismember('album:' .. album .. ':imagetags', itag) == 1 do
        itag = generate_tag()
    end

    local imagepath = path .. tag .. '/' .. itag .. '/'
    if not os.rename(imagepath, imagepath) then
        os.execute('mkdir -p ' .. imagepath)
    end
    
    local req_body_file_name = ngx.req.get_body_file()
    if not req_body_file_name then
        ngx.status = 403
        ngx.say('No file found in request')
        return
    end
    -- check if filename is image
    local pattern = '\\.(jpe?g|gif|png)$'
    if not ngx.re.match(file_name, pattern, "i") then
        ngx.status = 403
        ngx.say('Filename must be of image type')
        return
    end

    tmpfile = io.open(req_body_file_name)
    realfile = io.open(imagepath .. file_name, 'w')
    local size = 2^13      -- good buffer size (8K)
    while true do
      local block = tmpfile:read(size)
      if not block then break end
      realfile:write(block)
    end

    tmpfile:close()
    realfile:close()

    -- Save meta data to DB
    add_file_to_db(album, itag, h)

    -- load template
    local page = tload('uploaded.html')
    local context = ctx{}
    -- and return it to nginx
    ngx.print( page(context) )
end


--
-- return images from db
--
local function img()
    ngx.header.content_type = 'application/json';
    local albumskey = 'zalbums'
    local albums, err = red:zrange(albumskey, 0, -1)
    local res = {}
    res['albums'] = albums
    res['images'] = {}

    for i, album in ipairs(albums) do
        local images, err = red:zrange(album, 0, -1)
        res['images'] = images
        for i, image in ipairs(images) do
            local imgh, err = red:hgetall(image)
            res[image] = imgh
        end
    end

    ngx.print( cjson.encode(res) )
end

--
-- view to count clicks
--
local function api_img_click()
    local args = ngx.req.get_uri_args()
    local match = ngx.re.match(args['img'], '^/.*/(\\w+)/(\\w+)/(.+)$')
    if not match then
        return ngx.print('Faulty request')
    end
    atag = match[1]
    itag = match[2]
    img  = match[3]
    local key = itag .. '/' .. img
    local counter, err = red:hincrby(key, 'views', 1)
    if err then
        ngx.print (cjson.encode ({image=key,error=err}) )
        return
    end
    ngx.print (cjson.encode ({image=key,views=counter}) )
end

-- 
-- remove img
--
local function api_img_remove()
    ngx.header.content_type = 'application/json'
    local args = ngx.req.get_uri_args()
    local album = args['album']
    match = ngx.re.match(args['image'], '(.*)/(.*)')
    if not match then
        return ngx.print('Faulty image')
    end
    res = {}
    itag = match[1]
    img = match[2]
    tag = red:hget(album..'h', 'tag')
    -- delete image hash
    res['image'] = red:del(itag .. '/' .. img)
    -- delete itag from itag set
    res['itags'] = red:srem('album:' .. album .. ':imagetags', itag)
    -- delete image from album set
    res['images'] = red:zrem(album, itag .. '/' .. img)
    -- delete image and dir from file
    res['rmimg'] = os.execute('rm "' .. IMGPATH .. tag .. '/' .. itag .. '/' .. img .. '"')
    -- FIXME get real thumbnail filenames?
    -- delete thumbnail
    res['rmimg'] = os.execute('rm "' .. IMGPATH .. tag .. '/' .. itag .. '/t640.' .. img .. '"')
    res['rmdir'] = os.execute('rmdir ' .. IMGPATH .. tag .. '/' .. itag .. '/')

    res['album'] = album
    res['itag'] = itag
    res['tag'] = tag
    res['img'] = img

    ngx.print( cjson.encode ( res ) )
end

local function api_album_remove()
    ngx.header.content_type = 'application/json';
    local match = ngx.re.match(ngx.var.uri, '/(\\w+)/(\\w+)$')
    local tag = match[1]
    local album = match[2]
    if not tag or not album then
        return ngx.print('Faulty tag or album')
    end
    res = {
        tag = tag,
        album = album,
    }

    local images, err = red:zrange(album, 0, -1)
    --res['images'] = images

    for i, image in ipairs(images) do
        local imgh, err = red:del(image)
        res[image] = imgh
    end

    res['imagetags'] = red:del('album:'..album..':imagetags')
    for i, member in ipairs(red:smembers('album:' .. album .. ':accesstags')) do
        local accesstagkey = 'album:' .. album .. ':' .. member
        red[accesstagkey] = red:del(accesstagkey)
    end
    res['accesstags'] = red:del('album:'..album..':accesstags')
    res['album'] = red:del(album)
    res[album..'h'] = red:del(album..'h')

    res['albums'] = red:zrem('zalbums', album)
    res['command'] = "rm -rf "..IMGPATH..'/'..tag
    os.execute(res['command'])
    ngx.print( cjson.encode ( res ) )
end


-- 
-- Initialise db
--
local function init_db()
    -- Start redis connection
    red = redis:new()
    local ok, err = red:connect("unix:/var/run/redis/redis.sock")
    if not ok then
        ngx.say("failed to connect: ", err)
        return
    end
end

--
-- End db, we could close here, but park it in the pool instead
--
local function end_db()
    -- put it into the connection pool of size 100,
    -- with 0 idle timeout
    local ok, err = red:set_keepalive(0, 100)
    if not ok then
        ngx.say("failed to set keepalive: ", err)
        return
    end
end

-- mapping patterns to views
local routes = {
    ['albums/(\\w+)/'] = albums,
    ['albums/$']       = albums,
    ['(\\w+)/(\\w+)/$']= album,
    ['(\\w+)/(\\w+)/(\\d+)/$']= album,
    ['$']              = index,
    ['admin/$']        = admin,
    ['upload/$']       = upload,
    ['upload/post/?$'] = upload_post,
    ['api/img/?$']     = img,
    ['api/img/click/$'] = api_img_click,
    ['api/img/remove/(\\.*)'] = api_img_remove,
    ['api/album/remove/(\\.*)'] = api_album_remove,
}
-- iterate route patterns and find view
for pattern, view in pairs(routes) do
    local match = ngx.re.match(ngx.var.uri, '^' .. BASE .. pattern, "o") -- regex mather in compile mode
    if match then
        init_db()
        view(match)
        end_db()
        -- return OK, since we called a view
        ngx.exit( ngx.HTTP_OK )
    end
end
-- no match, log and return 404
ngx.log(ngx.ERR, '---***---: 404 with requested URI:' .. ngx.var.uri)
ngx.exit( ngx.HTTP_NOT_FOUND )
