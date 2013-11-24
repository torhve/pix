local redis = require "resty.redis"
local persona = require 'persona'

local config = ngx.shared.config

-- Only load config once. TODO Needs a /reload url to reload config / unset it.
if not config then
    local f = assert(io.open(ROOT_PATH .. "/etc/config.json", "r"))
    local c = f:read("*all")
    f:close()

    config = cjson.decode(c)
    ngx.shared.config = config
end

local function verify_access_key(red, key, album)
    local accesskey = 'album:' .. album .. ':' .. key
    local exists = red:exists(accesskey) == 1

    if exists then -- set correct expire headres
        local ttl = red:ttl(accesskey)
        ngx.header["Expires"] = ngx.http_time( ngx.time() + ttl)
        ngx.header["Cache-Control"] = "max-age=" .. ttl
    end


    return exists
end

local function exit(red, status)
    local ok, err = red:set_keepalive(0, 100)
    ngx.exit(status)
end

-- helper function to verify that the current user is logged in and valid
-- using persona
local function is_admin() 
    if persona.get_current_email() == config.admin then
        return true
    end
    return false
end

BASE = config.path.base
local red = redis:new()

local match = ngx.re.match(ngx.var.uri, "^/(album|img)/(\\w+)/([a-zA-Z0-9-_\\.]+)/(.*)?/?", "o")
if match then 
    local urltype = match[1]
    local key     = match[2]
    local album   = match[3]
    local img     = match[4]

    local ok, err = red:connect("unix:" .. config.redis.unix_socket_path)

    local verified = false
  
    -- IP based admin access
    if is_admin() then
        verified = true
    else
        verified = verify_access_key(red, key, album) 
    end

    if verified then
        local tag = red:hget(album .. 'h', 'tag')
        if urltype == 'album' then
            local uri = BASE .. 'album/' .. tag .. '/' .. album .. '/'
            if img then uri = uri ..  img end
            ngx.var.IMGBASE = '/img/' .. key .. '/'  .. album .. '/'
            --ngx.log(ngx.ERR, '---***---: rewrote URI:' .. ngx.var.uri .. '=>' .. uri)
            ngx.req.set_uri(uri)
        elseif urltype == 'img' then
            local uri = ngx.var.IMGBASE .. img
            --ngx.log(ngx.ERR, '---***---: rewrote URI:' .. ngx.var.uri .. '=>' .. uri)
            ngx.req.set_uri(uri)
        else
            --ngx.log(ngx.ERR, '---***---: 404 in rewriter with requested URI:' .. ngx.var.uri)
            exit(red, 404)
        end
    else 
        exit(red, 410)
    end
end
local ok, err = red:set_keepalive(0, 100)
-- 1 week cache
ngx.header["Expires"] = ngx.http_time( ngx.time() + 86400*7 )
--ngx.exit(404) 
