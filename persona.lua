---
-- Persona Lua auth backend using ngx location capture
-- also using postgresql capture for storing sessions to db
-- 
-- Copyright Tor Hveem <thveem> 2013
-- 
-- Nginx conf example:
-- location /persona/ {
--     internal;
--     proxy_set_header Content-type 'application/json';
--     proxy_pass 'https://verifier.login.persona.org:443/verify';
-- }
--
local setmetatable = setmetatable
local ngx = ngx
local cjson = require"cjson"
local sprintf = string.format
local substr = string.sub
local redis = require"resty.redis"


module(...)

local mt = { __index = _M }

-- db global
local red

-- 
-- Initialise db
--
local function init_db()
    -- Start redis connection
    red = redis:new()
    if ngx.shared.config.redis.unix_socket_path then
        local ok, err = red:connect("unix:" .. ngx.shared.config.redis.unix_socket_path)
        if not ok then
            ngx.log(ngx.ERR, "failed to connect: ", err)
            return 'Redis error', 403
        end
    end
end

--
-- End db, park it in the pool instead
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

function verify(assertion, audience)

    local vars = {
        assertion=assertion,
        audience=audience,
    }
    local options = {
        method = ngx.HTTP_POST,
        body = cjson.encode(vars)
    }

    local res, err = ngx.location.capture('/persona/', options);

    if not res then
        return { err = res }
    end

    if res.status >= 200 and res.status < 300 then
        return cjson.decode(res.body)
    else
        return {
            status= res.status,
            body = res.body
        }
    end
end

function getsess(sessionid)
    --local res = db.dbreq("SELECT * FROM session WHERE sessionid = '"..sessionid.."'")
    init_db()
    local res = red:hgetall(sprintf('photongx:session:%s', sessionid))
    if res == ngx.null then
        return nil
    end
    res = red:array_to_hash(res)
    end_db()

    return res
end

local function setsess(personadata)
    -- Set cookie for session
    local sessionid = ngx.md5(personadata.email .. ngx.md5(personadata.expires))
    ngx.header['Set-Cookie'] = 'session='..sessionid..'; path=/; HttpOnly'
    init_db()
    local key = sprintf('photongx:session:%s', sessionid)
    local ok, err = red:hmset(key, {
        sessionid = sessionid,
        email = personadata.email,
        created = ngx.now(),
        expires = personadata.expires,
    })
    -- persona timestamp is javascript timestamp, so only use 10 first digits
    local ok, err = red:expireat(key, substr(personadata.expires, 1, 10))
    end_db()
end

function get_current_email()
    local cookie = ngx.var['cookie_session']
    if cookie then
        local sess = getsess(cookie)
        if sess then
            return sess.email
        end
    end
    return false
end

function login()
    ngx.req.read_body()
    -- app is sending application/json
    local body = ngx.req.get_body_data()
    if body then 
        local args = cjson.decode(body)
        local audience = 'pex.hveem.no'
        local personadata = verify(args.assertion, audience)
        if personadata.status == 'okay' then
            setsess(personadata)
        end
        -- Print the data back to client
        return cjson.encode(personadata)
    else
        return cjson.encode{ email = false} 
    end
end

function status()
    local cookie = ngx.var['cookie_session']
    if cookie then
        return ( cjson.encode(getsess(cookie)) )
    else
        return '{"email":false}'
    end
end

function logout()
    local cookie = ngx.var['cookie_session']
    if cookie then
        init_db()
        local ok, err = red:del(sprintf('photongx:session:%s', cookie))
        end_db()
        return 'true'
    else
        return 'false'
    end
end

local class_mt = {
    -- to prevent use of casual module global variables
    __newindex = function (table, key, val)
        ngx.log(ngx.ERR, 'attempt to write to undeclared variable "' .. key .. '"')
    end
}

setmetatable(_M, class_mt)
