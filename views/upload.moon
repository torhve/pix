import Widget from require "lapis.html"
class Index extends Widget
    content: =>
        div class: "body", ->
            h1  @title
