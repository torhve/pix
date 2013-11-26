lapis = require "lapis"
models = require "models"
import capture_errors from require "lapis.application"
import respond_to, capture_errors, capture_errors_json, assert_error, yield_error from require "lapis.application"
import validate, assert_valid from require "lapis.validate"
import escape_pattern, trim_filter from require "lapis.util"

require_login = (fn) ->
  =>
    if @current_user
      fn @
    else
      redirect_to: @url_for "user_login"

class extends lapis.Application
