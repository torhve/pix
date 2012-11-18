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

local function exit(status)
    local ok, err = red:set_keepalive(0, 100)
    ngx.exit(status)
end

BASE = '/'
--local cjson = require "cjson"
--ngx.log(ngx.ERR, cjson.encode(match))
local redis = require "resty.redis"
local red = redis:new()

local match = ngx.re.match(ngx.var.uri, "^/(album|img)/(\\w+)/(\\w+)/(.*)?", "o")
if match then 
    local urltype = match[1]
    local key     = match[2]
    --local tag     = match[3]
    local album   = match[3]
    local img     = match[4]

    local ok  = red:connect("unix:/var/run/redis/redis.sock")
    
    local verified = verify_access_key(red, key, album) 

    if verified then
        local tag = red:hget(album .. 'h', 'tag')
        if urltype == 'album' then
            local uri = BASE .. 'album/' .. tag .. '/' .. album .. '/'
            ngx.var.IMGBASE = '/img/' .. key .. '/'  .. album .. '/'
            ngx.log(ngx.ERR, '---***---: rewrote URI:' .. ngx.var.uri .. '=>' .. uri)
            ngx.req.set_uri(uri)
        elseif urltype == 'img' then
            local uri = ngx.var.IMGBASE .. img
            ngx.log(ngx.ERR, '---***---: rewrote URI:' .. ngx.var.uri .. '=>' .. uri)
            ngx.req.set_uri(uri)
        else
            ngx.log(ngx.ERR, '---***---: 404 in rewriter with requested URI:' .. ngx.var.uri)
            exit(404)
        end
    else 
        exit(410)
    end
end
local ok, err = red:set_keepalive(0, 100)
-- 1 week cache
ngx.header["Expires"] = ngx.http_time( ngx.time() + 86400*7 )
--ngx.exit(404) 
