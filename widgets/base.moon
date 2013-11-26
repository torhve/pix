import Widget from require "lapis.html"

class Base extends Widget
  render_errors: =>
    if @errors
      div "Errors:"
      ul ->
        for e in *@errors
          li e
