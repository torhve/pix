$(function(){

    var $container = $('.items');
    
    $container.imagesLoaded(function( $images, $proper, $broken ) {
        console.log('hello from loaded');
        $container.isotope({
            animationEngine: 'css',
            // masonry: { columnWidth: $container.width() / 3 }
//                masonry: { columnWidth: $(document).width() > 1225 ? 146 : 113  }
        });
    });

   //masonry: { columnWidth: $(document).width() > 1225 ? 146 : 113 
                //resizable: false, // disable normal resizing
    
    $('.lb').click(function(e) {
        
        //prevent default action (hyperlink)
        e.preventDefault();
        
        //Get clicked link href
        var image_href = $(this).attr("href");
        
        /*  
        If the lightbox window HTML already exists in document, 
        change the img src to to match the href of whatever link was clicked
        
        If the lightbox window HTML doesn't exists, create it and insert it.
        (This will only happen the first time around)
        */
        $('.spinner').removeClass('hidden');
        
        if ($('#lightbox').length > 0) { // #lightbox exists

            //place href as img src value
            $('#content').html('<img src="' + image_href + '" />');
            

        } else { //#lightbox does not exist - create and insert (runs 1st time only)
            
            //create HTML markup for lightbox window
            var lightbox = 
            '<div id="lightbox" class="hidden">' +
                '<p><i class="icon-resize-small"></i></p>' +
                '<div id="content">' + //insert clicked link's href into img src
                    '<img src="' + image_href +'" />' +
                '</div>' +  
            '</div>';
                
            //insert lightbox HTML into page
            $('body').append(lightbox);

        }
        $('#content').imagesLoaded(function( $images, $proper, $broken ) {
            console.log('hello from lb loaded');
            // effects for background
            $('.items').addClass('backgrounded');
            //show lightbox window - you could use .show('fast') for a transition
            $('#lightbox').removeClass('hidden').show();
            $('.spinner').addClass('hidden');
        });

    });
        
    var hideLB = function() {
        // effects for background
        $('.items').removeClass('backgrounded');
        //$('#lightbox').hide();
        $('#lightbox').hide();
    };
    
    //Click anywhere on the page to get rid of lightbox window
    $('#lightbox').live('click', hideLB);  //must use live, as the lightbox element is inserted into the DOM

    window.document.onkeydown = function (e) {
      if (!e)
          e = event;
    if (e.keyCode == 27)
        hideLB();
    }
});
