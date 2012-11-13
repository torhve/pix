// proper column size
$('.item').css('max-width', ($(document).width()/3)-8 + 'px');
$('.item img').css('width', ($(document).width()/3)-8 + 'px');

var $container = $('.items');
$(window).smartresize(function(){
    $('.item').css('max-width', ($(document).width()/3)-8 + 'px');
    $('.item img').css('width', ($(document).width()/3)-8 + 'px');
    $container.isotope({
        resizable: false, // disable normal resizing
        animationEngine: 'css' // Must use css, or no animation at all

    });
});


var currentimage = 0;

$.fn.preload = function() {
    this.each(function(){
        // Check if url starts with /
        if (this[0] == '/') {
            console.log(String(this));
            $('<img>')[0].src = this;
        }
    });
}

$(function(){
    window.currentimage = 0;

    
    $container.imagesLoaded(function( $images, $proper, $broken ) {
        console.log('hello from loaded');
        $container.isotope({
            resizable: false, // disable normal resizing
            animationEngine: 'css' // Must use css, or no animation at all

        });
    });
//              layoutMode: 'cellsByRow',
//              cellsByRow: {
//                      columnWidth: 240,
//                rowHeight: 360

    
    $('.lb').click(function(e) {
        // Show spinner
        $('#spinner').removeClass('hidden');
        
        //prevent default action (hyperlink)
        e.preventDefault();
        
        //Get clicked link href
        var image_href = $(this).attr("href");

        // Save the current image
        window.currentimage = parseInt($(this).attr('id').split('-')[1]);
        
        
        /*  
        If the lightbox window HTML already exists in document, 
        change the img src to to match the href of whatever link was clicked
        
        If the lightbox window HTML doesn't exists, create it and insert it.
        (This will only happen the first time around)
        */
        
        if ($('#lightbox').length > 0) { // #lightbox exists

            setLBimage(image_href);
            

        } else { //#lightbox does not exist - create and insert (runs 1st time only)
            
            //create HTML markup for lightbox window
            var lightbox = 
            '<div id="lightbox" class="hidden">' +
                '<p><a id="goFS" href="#"><i class="icon-fullscreen"></i></a> <i class="icon-remove"></i></p>' +
                '<div id="content">' + //insert clicked link's href into img src
                    '<img src="' + image_href +'" />' +
                '</div>' +  
            '</div>';
                
            //insert lightbox HTML into page
            $('body').append(lightbox);

        }

        showLB();

    });
    var setLBimage = function(image_href) {
        //place href as img src value
        $('#content').html('<img src="' + image_href + '" />');
    };
    var showLB = function() {
        $('#content').imagesLoaded(function( $images, $proper, $broken ) {
            console.log('hello from lb loaded');
            // effects for background
            $('.items').addClass('backgrounded');
            //show lightbox window - you could use .show('fast') for a transition
            $('#lightbox').removeClass('hidden').show();
            // We are loaded, so hide the spinner
            $('.spinner').addClass('hidden');
        });
    };
        
    var hideLB = function() {
        // effects for background
        $('.items').removeClass('backgrounded');
        //$('#lightbox').hide();
        $('#lightbox').hide();
    };
    
    //Click anywhere on the page to get rid of lightbox window
    $('#lightbox').live('click', hideLB);  //must use live, as the lightbox element is inserted into the DOM
    //
    
    var goFS = function() {
        console.log('Going Fullscreen');
        var elem = document.getElementById("lightbox");

        if (elem.requestFullScreen) {
            elem.requestFullScreen();
        } else if (elem.mozRequestFullScreen) {
            elem.mozRequestFullScreen();
        } else if (elem.webkitRequestFullScreen) {
            elem.webkitRequestFullScreen();
        }
    }


    // Click handler for fullscreenbutton
    // Bind using body since dynamic element
    $('body').bind('click', function() {
        if ($(this).attr('id') == 'goFS') {
            goFS();
        }
    });

    $(document).keydown(function(e){
      if (e.keyCode == 27) { 
          hideLB();
          return false;
      }
      else if (e.keyCode == 37 || e.keyCode == 39) {
          var c;
          if (e.keyCode == 37) {
              c = currentimage - 1;
          }
          else if (e.keyCode == 39) {
              c = window.currentimage + 1;
          }
          window.currentimage = c;
          var image_href = $('#image-'+c).attr('href');
          setLBimage(image_href);
          $([
              $('#image-'+String(parseInt(c+1))).attr('href'),
              $('#image-'+String(parseInt(c+2))).attr('href'),
              $('#image-'+String(parseInt(c+3))).attr('href')
          ]).preload();
          return false;
      }
      else if (e.keyCode == 70) {
          goFS();
      }
    });

});
