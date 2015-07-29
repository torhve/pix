import config from require "lapis.config"


json_file = (fname) ->
  json = require "cjson"
  file = assert io.open fname
  with json.decode file\read "*a"
    file\close!


config {"production", "development"}, ->
  for k,v in pairs json_file "etc/config.json"
    set k, v

config "development", ->
    port 8080

config "production", ->
    port 8080
    lua_code_cache on
 
--c = require("lapis.config").get "development"
--print c.site.name
