import Widget from require "lapis.html"

class Layout extends Widget
  content: =>
    html_5 ->
      head ->
        meta charset: "utf-8"
        title ->
          if @title
            text "PIX #{@title}"
          else
            text "PIX"

        if @description
          meta name: "description", content: @description

        link rel: "stylesheet", href: "/static/screen.css"
        script type: "text/javascript", src: "//ajax.googleapis.com/ajax/libs/jquery/2.0.3/jquery.min.js"
        script type: "text/javascript", src: "/static/main.js"

      body ->
          nav class: "top-bar", ->
            ul class: "title-area", ->
                li class: "name", ->
                    h1 -> a href: @url_for"index", "PIX"
                li class:"toggle-topbar menu-icon", ->
                    a href:"#", ->
                     span "Menu"
          div class: "", ->
            @content_for "inner"

