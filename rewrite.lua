local match = ngx.re.match(ngx.var.uri, "^/album/(\\w+)/(\\w+)/(\\w+)/$", "o")
if not match then ngx.exit(404) end
local redis = require "resty.redis"
local accesskey = 'album:' .. match[3] .. ':' .. match[1]
local red = redis:new()
local ok  = red:connect("unix:/var/run/redis/redis.sock")
local exists = red:exists(accesskey) == 1
local ok, err = red:set_keepalive(0, 100)
if exists then
    local uri = '/photongx/' .. match[2] .. '/' .. match[3] .. '/'
    ngx.req.set_uri(uri)
else
    ngx.exit(410)
end
