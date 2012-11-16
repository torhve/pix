local function verify_access_key(key, album)
    local redis = require "resty.redis"
    local accesskey = 'album:' .. album .. ':' .. key
    local red = redis:new()
    local ok  = red:connect("unix:/var/run/redis/redis.sock")
    local exists = red:exists(accesskey) == 1
    local ok, err = red:set_keepalive(0, 100)
    return exists
end

BASE = '/'
--local cjson = require "cjson"
--ngx.log(ngx.ERR, cjson.encode(match))

local match = ngx.re.match(ngx.var.uri, "^/(album|img)/(\\w+)/(\\w+)/(\\w+)/(.*)?", "o")
if match then 
    local urltype = match[1]
    local key     = match[2]
    local tag     = match[3]
    local album   = match[4]

    if verify_access_key(key, album) then
        if urltype == 'album' then
            local uri = BASE .. tag .. '/' .. album .. '/'
            ngx.var.IMGBASE = '/img/' .. key .. '/' .. tag .. '/' .. album .. '/'
            ngx.req.set_uri(uri)
        elseif urltype == 'img' then
            local uri = ngx.var.IMGBASE .. match[5]
            ngx.req.set_uri(uri)
        else
            ngx.exit(404)
        end
    else 
        ngx.exit(410)
    end
end
--ngx.exit(404) 
