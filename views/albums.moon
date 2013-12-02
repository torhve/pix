import Widget from require "lapis.html"
class Albums extends Widget
    content: =>
      if @current_user
        div class:"", ->
          div class:"header vertical-line", ->
            div class:"", ->
              a href:"/admin/", ->
                span class:"blue", ->
                  text "Photo Engine X "
                text "Administration "
                span class:"pull-right", ->
                  text "Logged in as " .. @current_user.email

      div class:"items", ->
        for index, album in pairs @albums 
         -- Skip albums with no images in them
         unless album.image
           continue
         div class:"item", ->
            a href:album.url, -> 
              img src:@url_for("img", token:album.image.token, filename:album.image.thumb_name)
            div class:"album-label", ->
              a href:album.url, ->
                i class:"fa fa-camera-retro"
                text " "..album.title
      div id:"spinner", class:"spinner", ->
        text "Loading ..."
      raw [[
      <script>
      $(document).on("ready", function (evt) {
          pnx = photongx($('.items'), $('.item'));
      });
      </script>
      ]]
