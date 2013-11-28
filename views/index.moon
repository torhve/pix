import Widget from require "lapis.html"
class Index extends Widget
  content: =>
    div id:"about",class: "body container-fluid", ->
      h1 class:"white", ->
        text "Photo Engine"
        span class:"blue", ->
          text ' X '
        small "the little gallery that could"
      div class:"row-fluid", ->
        div class:"span6", ->
          img src:"/static/pex.png"
        div class:"span6", ->
            h2 "Features"
            ul class:"unstyled", ->
              raw [[
                <li><i class="fa fa-check"></i>Full width thumbnails</li>
                <li><i class="fa fa-check"></i>Responsive design</li>
                <li><i class="fa fa-check"></i>Simplistic interface</li>
                <li><i class="fa fa-check"></i>Expirable URLs for albums</li>
                <li><i class="fa fa-check"></i>Super fast</li>
                <li><i class="fa fa-check"></i>Open source</li>
                <li><i class="fa fa-check"></i>Backend in <a href="http://luajit.org/luajit.html">lua</a></li>
                <li><i class="fa fa-check"></i><a href="http://redis.io">Redis</a> as database</li>
                <li><i class="fa fa-check"></i>Runs on <a href="http://openresty.org/">nginx (openresty)</a></li>
                <li><i class="fa fa-check"></i><a href="https://login.persona.org/about">Persona</a> for login</li>
                <li><i class="fa fa-check"></i><a href="http://angularjs.org/">AngularJS</a> admin panel</li>
                <li><i class="fa fa-check"></i>Is awesome!</li>
              ]]
            raw [[
              <div class="actions">
                  <a class="btn btn-primary btn-large" href="/admin/"><i class="fa fa-arrow-right"></i> Log in</a>
                  <a class="btn btn-primary btn-large" href="https://github.com/torhve/photongx/"><i class="fa fa-github"></i> View project on github</a>
              </div>
              ]]
      div class:"row-fluid", ->
        footer class:"footer span12", ->
          raw [[
              &copy; 2012-2013 <a href="mailto:tor@h%76e%65m%2Eno"><i class="fa fa-envelope-o"></i> Tor Hveem</a>
          ]]

        
