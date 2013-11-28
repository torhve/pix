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
        else
          meta name:"description", content:"Photo engine X"

        link rel: "stylesheet", href: "/static/screen.css"
        link href:"/static/fa/css/font-awesome.css", rel:"stylesheet"
        meta name:"viewport", content:"width:device-width, initial-scale=1.0"
        meta name:"author", content:"Tor Hveem"
        link rel:"shortcut icon", type:"image/png", href:"/static/favicon.png"
        link rel:"icon", type:"image/png", href:"/static/favicon.png"

        script type: "text/javascript", src: "//ajax.googleapis.com/ajax/libs/jquery/2.0.3/jquery.min.js"
        raw [[
        <!-- HTML5 shim, for IE6-8 support of HTML5 elements -->
        <!--[if lt IE 9]>
          <script src="http://html5shim.googlecode.com/svn/trunk/html5.js"></script>
        <![endif]-->
        ]]

      body ->
        div class: "", ->
          @content_for "inner"
        script type:"application/javascript",src:"/static/smartresize/jquery.debouncedresize.js"
        script type:"application/javascript",src:"/static/imagesloaded/jquery.imagesloaded.min.js"
        script type:"application/javascript",src:"/static/wookmark/jquery.wookmark.min.js"
        script type:"application/javascript",src:"/static/photongx.js"

