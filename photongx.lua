--[
--
-- Photo Engine X
-- (C) 2012-2013 Tor Hveem
-- License: 3-clause BSD
--
-- This file includes part of the tir template engine by Zed Shaw
--
--]

local cjson = require"cjson"
local math  = require"math"
local redis = require"resty.redis"
local template = require "template"
local resty_md5 = require "resty.md5"
local rupload = require "resty.upload"
local rstr = require "resty.string"
local persona = require 'persona'

local ROOT_PATH = ngx.var.root
local config = ngx.shared.config

-- Only load config once. TODO Needs a /reload url to reload config / unset it.
if not config then
    local f = assert(io.open(ROOT_PATH .. "/etc/config.json", "r"))
    local c = f:read("*all")
    f:close()

    config = cjson.decode(c)
    ngx.shared.config = config
end


TEMPLATEDIR = ROOT_PATH .. '/';

-- db global
red = nil
-- BASE path global
BASE = config.path.base
-- IMG base path
IMGPATH = ROOT_PATH .. config.path.image .. '/'
-- Default tag length global
TAGLENGTH = 6

-- Default context helper
function ctx(ctx)
    ctx['BASE'] = BASE
    ctx['IMGBASE'] = config.path.image
    return ctx
end

-- KEY SCHEME
-- albums            z: zalbums                    = set('albumname', 'albumname2', ... )
-- tags              h: albumnameh                 = 'tag'
-- album             z: albumname                  = set('itag/filename', 'itag2/filename2', ...)
-- images            h: itag/filename              = {album: 'albumname', timestamp: ... ... }
-- album image tags  s: album:albumname:imagetags  = ['msdf90', 'bsdf90', 'cabcdef', ...]
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


-- helper function to verify that the current user is logged in and valid
-- using persona
function is_admin() 
    if persona.get_current_email() == config.admin then
        return true
    end
    return false
end

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
    if not filename then return nil end
    filename = string.gsub(filename, '/', '')
    filename = string.gsub(filename, '%.%.', '')
    -- Filenames with spaces are just a hassle
    filename = string.gsub(filename, ' ', '_')
    -- Strip all nonascii
    filename = string.gsub(filename, '[^_,%-%.a-zA-Z0-9]', '')
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
function verify_tag(tag, length)
    if not length then length = TAGLENGTH end
    if not tag then return false end
    if #tag < length then return false end
    if not ngx.re.match(tag, '^[a-zA-Z0-9]+$') then return false end
    return true
end

function verify_access_key(key, album)
    local accesskey = 'album:' .. album .. ':' .. key
    local exists = red:exists(accesskey) == 1
    return exists
end


-- Help to set content type and compile to JSON
function json(str) 
    ngx.header.content_type = 'application/json';
    return cjson.encode(str)
end


--
--
-- ******* VIEWS ******* 
--



-- 
-- Albums view
--
local function albums(match)
    local accesstag = match[1]
    local albums = getalbums(accesstag)

    local images = {}
    local tags  = {}
    local atags = {}
    local imagecount = 0

    -- Fetch a cover img
    for i, album in ipairs(albums) do
        -- FIXME, only get 1 image
        local theimages, err = red:zrange(album, 0, 1)
        imagecount = imagecount + #theimages
        if err then
            ngx.say(err)
            return
        end
        local tag, err = red:hget(album .. 'h', 'tag')
        -- If accesstag is set, we use that as access for every album
        if accesstag then 
            atags[album] = accesstag
        else
            local tag, err = red:hget(album .. 'h', 'tag')
            atags[album] = tag
        end
        tags[album] = tag
        for i, image in ipairs(theimages) do
            local itag = red:hget(image, 'itag')
            -- Get thumb if key exists
            -- set to full size if it doesn't exist
            local img = ngx.var.IMGBASE .. accesstag .. '/' .. album .. '/' .. tag .. '/' ..  itag .. '/'  
            local thumb_name = red:hget(image, 'thumb_name')
            if thumb_name ~= ngx.null then
                images[album] = img .. thumb_name
            else
                images[album] = img .. red:hget(image, 'file_name')
            end
            break
        end
    end

    -- load template
    local page = template.tload('albums.html')
    local context = ctx{
        albums = albums, 
        imagecount = imagecount,
        images = images, 
        atags = atags,
        tags = tags,
        accesstag = accesstag,
        bodyclass = 'gallery'
    }
    -- render template with counter as context
    -- and return it to nginx
    return page(context) 
end

-- 
-- About view
--
local function index()
    -- load template
    local page = template.tload('main.html')
    local context = ctx{
        bodyclass = 'gallery',
    }
    -- render template with counter as context
    -- and return it to nginx
    return page(context)
end

--
-- View for a single album
-- 
local function album(path_vars)

    local tag = path_vars[1]
    local album = path_vars[2]
    local image_num = path_vars[3]
    -- Verify tag
    local dbtag, err = red:hget(album .. 'h', 'tag')
    if dbtag ~= tag then
        ngx.exit(410)
    end

    local imagelist, err = red:zrange(album, 0, -1)
    local images = {} -- Table holding full size images
    local thumbs = {} -- Table holding thumbnails

    for i, image in ipairs(imagelist) do
        local itag = red:hget(image, 'itag')
        -- Get thumb if key exists
        -- set to full size if it doesn't exist
        local thumb_name = red:hget(image, 'thumb_name')
        if thumb_name ~= ngx.null then
            thumbs[image] = itag .. '/' .. thumb_name
        else
            thumbs[image] = itag .. '/' .. red:hget(image, 'file_name')
        end
        -- Get the huge image if it exists
        local huge_name = red:hget(image, 'huge_name')
        if huge_name ~= ngx.null then
            images[image] = itag .. '/' .. huge_name
        else 
            images[image] = itag .. '/' .. red:hget(image, 'file_name')
        end
    end
    
    -- load template
    local page = template.tload('album.html')
    local context = ctx{ 
        album = album,
        tag = tag,
        albumtitle = ngx.re.gsub(album, '_', ' '),
        images = images,
        imagelist = imagelist,
        thumbs = thumbs,
        bodyclass = 'gallery',
        showimage = image_num,
    }
    -- render template with counter as context
    -- and return it to nginx
    return page(ctx(context))
end

--
-- A view that display a upload form
--
local function upload()
    -- load template
    local page = template.tload('upload.html')
    local args = ngx.req.get_uri_args()

    -- generate tag to make guessing urls non-worky
    local tag = generate_tag()

    local context = ctx{album=args['album'], tag=tag}
    -- and return it to nginx
    return page(context)
end

-- 
-- Admin API json queue length
--
local function admin_api_queue_length()
    if not is_admin() then return 'You must be logged in', 403 end
    return cjson.encode{ counter = red:llen('queue:thumb') }
end

-- 
-- Admin API json
--
local function admin_api_albumttl()
    if not is_admin() then return 'You must be logged in', 403 end
    local args = ngx.req.get_uri_args()
    local album = args['album']
    local accesstag = args['name']
    if not verify_tag(accesstag, 3) then
        accesstag = generate_tag()
    end

    local ttl = tonumber(args['ttl'])

    h = {}
    h['granted'] = ngx.now()
    h['expires'] = ttl

    local ok1, err1 = red:sadd(  'album:' .. album .. ':accesstags', accesstag)
    local ok2, err2 = red:hmset( 'album:' .. album .. ':' .. accesstag, h)

    -- if the arg is forever, the ttl isn't a number, and the expire will fail
    -- which means it will never expire
    local ok3, err3 = red:expire('album:' .. album .. ':' .. accesstag, ttl)

    res = {
        sadd  = ok1,
        hmset = ok2,
        expire= ok3,
    }

    return json(res)
end



local function add_file_to_db(album, itag, atag, file_name)
    local imgh       = {}
    local timestamp  = ngx.time() -- FIXME we could use header for this
    imgh['album']    = album
    imgh['atag']     = atag
    imgh['itag']     = itag
    imgh['timestamp']= timestamp
    imgh['client']   = ngx.var.remote_addr
    imgh['file_name']= file_name
    local albumskey  = 'zalbums' -- albumset
    local albumkey   =  album    -- image set
    local albumhkey  =  album .. 'h' -- album metadata
    local imagekey   =  imgh['itag'] .. '/' .. imgh['file_name']
    local itagkey    =  'album:' .. album .. ':imagetags'

    red:zadd(albumskey, timestamp, albumkey) -- add album to albumset
    red:zadd(albumkey , timestamp, imagekey) -- add imey to imageset
    red:sadd(itagkey, itag)                  -- add itag to set of used itags
    red:hmset(imagekey, imgh)                -- add imagehash
    red:hsetnx(albumhkey, 'tag', atag) -- only set tag if not exist

    red:lpush('queue:thumb', imagekey)       -- Add the uploaded image to the queue
end

--
-- View that recieves data from upload page
--
local function upload_post_handler()

    local chunk_size = 4096
    local form       = rupload:new(chunk_size)
    local md5        = resty_md5:new()
    local h          = ngx.req.get_headers()
    local fmd5       = h['X-Checksum'] 
    local file_name  = h['X-Filename']
    local referer    = h['referer']
    local album      = h['X-Album']
    local tag        = h['X-Tag']
    local itag       = generate_tag()  -- Image tag
    local file

    -- None unsecure shall pass
    file_name = secure_filename(file_name)
    -- check if filename is image
    local pattern = '\\.(jpe?g|gif|png)$'
    if not ngx.re.match(file_name, pattern, "i") then
        return 'Filename must be of image type', 403
    end
    -- Find unused tag if already in use
    while red:sismember('album:' .. album .. ':imagetags', itag) == 1 do
        itag = generate_tag()
    end

    -- Tags needs to be checked too
    if not verify_tag(tag) then
        return 'Invalid tag specified', 403
    end

    -- We want safe album names too
    album = secure_filename(album)

    -- Check if tag is OK
    local albumhkey =  album .. 'h' -- album metadata
    red:hsetnx(albumhkey, 'tag', tag)

    local atag, err = red:hget(albumhkey, 'tag')
    if atag ~= tag then
        return 'Wrong tag used when uploading', 403
    end

    local path  = IMGPATH

    if file_name then
        local albumpath = path .. atag .. '/' .. album
        -- simple trick to check if path exists
        if not os.rename(path .. tag, path .. atag) then
            os.execute('mkdir -p ' .. path .. atag)
        end
        if not os.rename(albumpath, albumpath) then
            os.execute('mkdir -p ' .. albumpath)
        end

        local imagepath = path .. tag .. '/' .. itag .. '/'
        if not os.rename(imagepath, imagepath) then
            os.execute('mkdir -p ' .. imagepath)
        end

        file = io.open(imagepath .. file_name, 'w+')

        if not file then
            return string.format('Failed to open file: %s', file_name), 403
        end
    end

    while true do
        local typ, res, err = form:read()
        if not typ then
             ngx.log(ngx.ERR, "failed to read: ", err)
             return
        end
        if typ == "header" then
            -- do nothing we use request headers instead of form data for all our values

        elseif typ == "body" then
            if file then
                file:write(res)
                md5:update(res)
            end

        elseif typ == "part_end" then
            file:close()
            file = nil
            local md5_sum = rstr.to_hex(md5:final())
            md5:reset()
            if md5_sum ~= fmd5 then
                ngx.log(ngx.ERR, string.format('MD5 sum did not match, our:%s, theirs:%s', md5_sum, fmd5))
            end
            -- Save meta data to DB
            add_file_to_db(album, itag, tag, file_name)
            
        elseif typ == "eof" then
            break

        else
            -- do nothing
        end
    end


    -- load template
    local page = template.tload('uploaded.html')
    -- and return it to nginx
    return page{}
end


--
-- return images from db
--
local function admin_api_images()
    if not is_admin() then return 'You must be logged in', 403 end
    local albumskey = 'zalbums'
    local albums, err = red:zrange(albumskey, 0, -1)
    local res = {}
    res['images'] = {}
    for i, album in ipairs(albums) do
        local images, err = red:zrange(album, 0, -1)
        for i, image in ipairs(images) do
            local imgh, err = red:hgetall(image)
            res[image] = red:array_to_hash(imgh)
        end
    end

    return json(res)
end

--[
-- Admin API all, api function to return all infos from db, tags, thumbs, images, accesskeys, imagecount, etc
-- ]]
local function admin_api_all()
    if not is_admin() then return 'You must be logged in', 403 end
    local albums = getalbums()
    local tags  = {}
    local images = {}
    local thumbs = {}
    local accesskeys = {}
    local accesskeysh = {}

    for i, album in ipairs(albums) do
        local theimages, err = red:zrange(album, 0, -1)
        local tag,       err = red:hget(album .. 'h', 'tag')
        local accesskeyl, err = red:smembers('album:' ..album .. ':accesstags')
        tags[album] = tag
        images[album] = theimages
        accesskeys[album] = accesskeyl
        accesskeysh[album] = {}
        for i, key in ipairs(accesskeyl) do 
            accesskeysh[album][key] = red:hgetall('album:' .. album .. ':' .. key)
        end
        thumbs[album] = {}
        for i, image in ipairs(theimages) do
            local itag = red:hget(image, 'itag')
            -- Get thumb if key exists
            -- set to full size if it doesn't exist
            local thumb_name = red:hget(image, 'thumb_name')
            if thumb_name ~= ngx.null then
                thumbs[album][image] = itag .. '/' .. thumb_name
            else
                local file_name = red:hget(image, 'file_name')
                if file_name ~= ngx.null then 
                    thumbs[album][image] = itag .. '/' .. file_name
                end
            end
        end
    end
    local res = {
        albums = albums,
        tags = tags,
        images = images,
        thumbs = thumbs,
        accesskeys = accesskeys,
        accesskeysh = accesskeysh,
    }
    return json(res)
end

--
-- return image from db
--
local function admin_api_image(match)
    if not is_admin() then return 'You must be logged in', 403 end
    local image = match[1]
    local res = {}
    local imgh, err = red:hgetall(image)
    res[image] = red:array_to_hash(imgh)
    return json(res)
end

--
-- 
--
local function admin_api_albums()
    if not is_admin() then return 'You must be logged in', 403 end
    local albumskey = 'zalbums'
    local albums = getalbums()
    local res = {}
    for i, album in ipairs(albums) do
        local dbtag, err = red:hget(album .. 'h', 'tag')
        table.insert(res, { 
            name = album,
            tag = dbtag,
        })
    end
    return json(res)
end

--
-- 
--
local function admin_api_album(match)
    if not is_admin() then return 'You must be logged in', 403 end
    local album = match[1]
    local dbtag, err = red:hget(album .. 'h', 'tag')
    local res = { 
        name = album,
        tag = dbtag
    }
    return json(res)
end

--
-- view to count clicks
--
local function api_img_click()
    local args = ngx.req.get_uri_args()
    local match = ngx.re.match(args['img'], '^/.*/(\\w+)/(\\w+)/(.+)$')
    if not match then
        return 'Faulty request', 404
    end
    atag = match[1]
    itag = match[2]
    img  = match[3]
    local key = itag .. '/' .. img
    local counter, err = red:hincrby(key, 'views', 1)
    if err then
        return {image=key,error=err}, 500
    end
    return json{image=key,views=counter}
end

-- 
-- API Function remove a single given image from a given album
--
local function api_img_remove()
    local args = ngx.req.get_uri_args()
    local album = args['album']
    match = ngx.re.match(args['image'], '(.*)/(.*)')
    if not match then
        return 'Faulty image', 401
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
    -- FIXME get thumb size from config
    res['rmimg'] = os.execute('rm -v "' .. IMGPATH .. tag .. '/' .. itag .. '/t640.' .. img .. '"')
    -- FIXME get thumb size from config
    res['rmimg'] = os.execute('rm -v "' .. IMGPATH .. tag .. '/' .. itag .. '/t2000.' .. img .. '"')
    res['rmdir'] = os.execute('rmdir -v ' .. IMGPATH .. tag .. '/' .. itag .. '/')

    res['album'] = album
    res['itag'] = itag
    res['tag'] = tag
    res['img'] = img

    return json(res)
end


--
-- API Function to remove an album
local function api_album_remove(match)
    local tag = match[1]
    local album = match[2]
    if not tag or not album then
        return 'Faulty tag or album', 401
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
    res['command'] = "rm -rfv "..IMGPATH..'/'..tag
    res['commandres'] = os.execute(res['command'])
    return json(res)
end

local function api_gentag(match) 
    local tag = generate_tag()
    return json{ tag=tag }
end


-- 
-- Initialise db
--
local function init_db()
    -- Start redis connection
    red = redis:new()
    if config.redis.unix_socket_path then
        local ok, err = red:connect("unix:" .. config.redis.unix_socket_path)
        if not ok then
            ngx.say("failed to connect: ", err)
            return
        end
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
    ['album/(\\w+)/(.+?)/$']  = album,
    ['album/(\\w+)/(.+?)/(\\d+)/$']= album,
    ['$']               = index,
    ['upload/$']        = upload,
    ['upload/post/?$']  = upload_post_handler,
    ['api/img/click/$'] = api_img_click,
    ['api/gentag/?$']   = api_gentag,
    ['api/persona/verify$'] = persona.login,
    ['api/persona/logout$'] = persona.logout,
    ['api/persona/status$'] = persona.status,
    ['admin/api/images/?$']= admin_api_images,
    ['admin/api/image/(.+)/?$']= admin_api_image,
    ['admin/api/albums/?$']= admin_api_albums,
    ['admin/api/album/remove/(\\w+)/(.+)$'] = api_album_remove,
    ['admin/api/album/(.+)$']= admin_api_album,
    ['admin/api/all/?$']= admin_api_all,
    ['admin/api/img/remove/(.*)'] = api_img_remove,
    ['admin/api/albumttl/create(.*)'] = admin_api_albumttl,
    ['admin/api/queue/length/'] = admin_api_queue_length,
}
-- Set the default content type
ngx.header.content_type = 'text/html';

-- iterate route patterns and find view
for pattern, view in pairs(routes) do
    local match = ngx.re.match(ngx.var.uri, '^' .. BASE .. pattern, "o") -- regex mather in compile mode
    if match then
        init_db()
        local ret, exit = view(match) 
        -- Print the returned res
        end_db()
        -- If not given exit, then assume OK
        if not exit then exit = ngx.HTTP_OK end
        -- Exit with returned exit value
        ngx.status = exit
        ngx.print(ret)
        ngx.exit( exit )
    end
end
-- no match, log and return 404
ngx.log(ngx.ERR, '---***---: 404 with requested URI:' .. ngx.var.uri)
ngx.exit( ngx.HTTP_NOT_FOUND )
