import Widget from require "lapis.html"
class Album extends Widget
    content: =>
      div class:"album-label", ->
        a href:@url_for("albums"), title:"Back to album list", ->
          i class:"fa fa-home"
          text " | " 
        a href:@url_for("album", token: @album.token, title:@album.title), ->
          i class:"fa fa-camera-retro"
          text " " ..@album.title
      div class:"items",->
        for index, image in pairs @images 
          div class:"item", ->
            a href:image\get_huge_url!, token:image.token, class:"lb", -> 
              img src:image\get_thumb_url!, title:"#{image.file_name} - #{image.views} views"
      div id:"spinner", class:"spinner", ->
        text "Loading ..."
      script ->
        raw "var album = '"..@album.title.."';"
        raw [[
        var showimage = false;
        //var showimage = {% if showimage then %}{{showimage}}{% else %}null{% end %};
        ]]
        raw [[
        $(document).on("ready", function (evt) {
            pnx = photongx($('.items'), $('.item'));
            if (showimage) {
                pnx.createLB();
                pnx.navigateImage(showimage);
                pnx.showLB();
            }
        });
        ]]
