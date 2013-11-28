import Widget from require "lapis.html"
class Error extends Widget
  content: =>
    div id:"about",class: "body container-fluid", ->
      h1 class:"white", ->
        text "Error #{@res.status}"
      h1 class:"white", ->
        text "Photo Engine"
        span class:"blue", ->
          text ' X '
      div class:"row-fluid", ->
        if @res.status == 403
          h2 "I'm sorry Dave, I'm afraid I can't do that"
        if @res.status == 404
          h2 "I'm sorry. But this isn't a valid address."
        if @res.status == 410
          h2 "Something used to be here. But now it isn't. My apologies."
