import Widget from require "lapis.html"
class Album extends Widget
    content: =>
      div class:"album-label", ->
        a href:@albumsurl, title:"Back to album list", ->
          i class:"fa fa-home"
          text " | " 
        a href:@albumurl, ->
          i class:"fa fa-camera-retro"
          text " " ..@album.title
      div class:"items",->
        for index, image in pairs @images 
          div class:"item", ->
            a href:image\get_huge_url!, token:image.token, class:"lb", -> 
              img src:image\get_thumb_url!, title:"#{image.file_name} - #{image.views} views"
              div class:"thumb-label", ->
                p image.file_name, ->
                  span class:"pull-right", "#{image.views } views"

      div id:"spinner", class:"spinner", ->
        text "Loading ..."
      script ->
        raw [[
        $(document).on("ready", function (evt) {
            pnx = photongx($('.items'), $('.item'));
        });
        ]]
