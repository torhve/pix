-- use nginx $root variable for template dir
local TEMPLATEDIR = ngx.var.root .. '/';

function escape(s)
    if s == nil then return '' end

    local esc, i = s:gsub('&', '&amp;'):gsub('<', '&lt;'):gsub('>', '&gt;')
    return esc
end

-- Simplistic Tir template escaping, for when you need to show lua code on web.
function tirescape(s)
    if s == nil then return '' end

    local esc, i = s:gsub('{', '&#123;'):gsub('}', '&#125;')
    return escape(esc)
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
-- Load redis
local redis = require "resty.redis"

-- Set the content type
ngx.header.content_type = 'text/html';


-- the db global
red = nil

-- 
-- Index view
--
local function index()
    
    -- increment index counter
    local counter = 0

    -- load template
    local page = tload('main.html')
    local context = {counter = tostring(counter) }
    -- render template with counter as context
    -- and return it to nginx
    ngx.print( page(context) )
end


--
-- hello world view
--
local function hello()
    ngx.print( tload('hello.html'){} )
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
    ['^/ngphotox/$']      = index,
}

-- iterate route patterns and find view
for pattern, view in pairs(routes) do
    if ngx.re.match(pattern, ngx.var.uri) then
        init_db()
        view()
        end_db()
        -- return OK, since we called a view
        ngx.exit( ngx.HTTP_OK )
    end
end
-- no match, return 404
ngx.exit( ngx.HTTP_NOT_FOUND )
