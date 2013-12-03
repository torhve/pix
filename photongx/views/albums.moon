import Widget from require "lapis.html"
class Albums extends Widget
    content: =>
      if @current_user
        div class:"container-fluid", ->
          div class:"row header vertical-line", ->
            div class:"col-md-12", ->
              a href:@url_for("admin"), ->
                span class:"blue", ->
                  text "Photo Engine" 
                  span class:"white", " X "
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
              img src:album.image\get_thumb_url!
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
