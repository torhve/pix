import Widget from require "lapis.html"
class Index extends Widget
  content: =>
    div class:"navbar navbar-inverse vertical-line", ->
      div class:"navbar-header", ->
        a class:"navbar-brand", href:'/', ->
          span class:"white", ->
            text "Photo Engine"
            span class:"blue", " X "
      ul class:"nav navbar-nav navbar-right", ->
        a class:"btn btn-default navbar-btn", href:@url_for("admin"), ->
          text "Get started "
          i class:"fa fa-arrow-right"
        li ->
          text ""
    div id:"about", class: "container", ->
      div class: "row", ->
        div class: "col-md-12", ->
          h1 class:"", ->
            text "Photo Engine"
            span class:"blue", ->
              text ' X '
            small "the little gallery that could"
          h3 "What is it ?"
          div ->
            p "A self hostable web gallery that lets you share your photos with the world."
            p ""
          h3 "Why ?"
          div ->
            p "Do not trust anyone but yourselv to keep your photos safe."
          raw [[
            <div class="actions">
                <a class="btn btn-primary btn-huge" href="/albums/demo/"><i class="fa fa-camera-retro"></i> Show me photos!</a>
            </div>
            ]]
      div class:"row", ->
        div class:"col-sm-6 col-md-6", ->
          h2 "Screenshot of albums"
          a class:"thumbnail", href:'/albums/demo/', ->
            img src:"/static/pex.png"
        div class:"col-sm-6 col-md-6", ->
          h2 "Features"
          ul class:"unstyled", ->
            raw [[
              <li><i class="fa fa-check"></i>Full width responsive design</li>
              <li><i class="fa fa-check"></i>Simplistic interface</li>
              <li><i class="fa fa-check"></i>Expirable URLs for albums</li>
              <li><i class="fa fa-check"></i>Drag & drop photo uploading</li>
              <li><i class="fa fa-check"></i>Super fast</li>
              <li><i class="fa fa-check"></i>Open source, free software</li>
              <li><i class="fa fa-check"></i>Backend written in <a href="http://luajit.org/luajit.html">MoonScript/lua</a></li>
              <li><i class="fa fa-check"></i><a href="http://leafo.net/lapis">Lapis</a> web framework</li>
              <li><i class="fa fa-check"></i><a href="http://postgresql.org">PostgreSQL</a> as database</li>
              <li><i class="fa fa-check"></i><a href="http://redis.io">Redis</a> for queue</li>
              <li><i class="fa fa-check"></i><a href="http://openresty.org/">nginx (openresty)</a> as the app server</li>
              <li><i class="fa fa-check"></i><a href="http://angularjs.org/">AngularJS</a> admin dashboard</li>
              <li><i class="fa fa-check"></i>Is awesome!</li>
            ]]
          raw [[
            <div class="actions">
              <a class="btn btn-primary btn-huge" href="/admin/">Get started <i class="fa fa-arrow-right"></i> </a>
              <a class="btn btn-primary btn-huge" href="https://github.com/torhve/pix/"><i class="fa fa-github"></i> View project on github</a>
            </div>
              ]]
      div class:"row", ->
        footer class:"footer cold-md-12", ->
          raw [[
              &copy; 2012-2013 <a href="mailto:tor@h%76e%65m%2Eno"><i class="fa fa-envelope-o"></i> Tor Hveem</a>
          ]]

       
