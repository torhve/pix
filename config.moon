import config from require "lapis.config"

config "development", ->
  port 8080
  postgresql_url "postgres://pix:pixplzpixplzpixplz@127.0.0.1/pix"
  redis {"127.0.0.1", 6379}
  session_name "pix_session"
  secret "ongalabongala pixala"
  imgpath "img"
  diskimgpath "/home/xt/src/pix/img"
  upload_size "64M"
  site "pix.hveem.no"
  redis_prefix "pix"

config "production", ->
  port 80
  num_workers 2
  lua_code_cache "off"
  postgresql_url "postgres://pix:pixplzpixplzpixplz@127.0.0.1/pix"
  redis {"127.0.0.1", 6379}
  session_name "pix_session"
  secret "pix"
  imgpath "img"
  diskimgpath "/home/xt/src/pix/img"
  upload_size "64M"
  site "pix.hveem.no"
  redis_prefix "pix"
