var currentimage = 0;
$(function(){
    window.currentimage = 0;

    var $container = $('.items');
    
    $container.imagesLoaded(function( $images, $proper, $broken ) {
        console.log('hello from loaded');
        $container.isotope({
            animationEngine: 'css', // Must use css, or no animation at all
        });
    });

    
    $('.lb').click(function(e) {
        // Show spinner
        $('#spinner').removeClass('hidden');
        
        //prevent default action (hyperlink)
        e.preventDefault();
        
        //Get clicked link href
        var image_href = $(this).attr("href");

        // Save the current image
        window.currentimage = parseInt($(this).data('image'));
        
        
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
        var elem = $('#lightbox');
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
          var image_href = $('a[data-image='+c+']').attr('href');
          setLBimage(image_href);
          return false;
      }
      else if (e.keyCode == 70) {
          goFS();
      }
    });

});
