$(function(){
    $.fn.preload = function() {
        this.each(function(){
            // Check if url starts with /
            if (this[0] == '/') {
                //console.log(String(this));
                $('<img>')[0].src = this;
            }
        });
    }
    $(window).on("debouncedresize", function(event) {
        setColumnwidth();
        /*
        $container.isotope({
            itemSelector: '.item',
            resizable: false, // disable normal resizing
            animationEngine: 'css' // We want css, or no animation at all
        });
        */
            $('.item').wookmark({
                container: $('.items'),
                autoResize: false,
                offset: 6
            });
    });


    var slideshow = false;
    var $container = $('.items');
    var currentimage = 0;
    var slideshowtimer;
    var interval = 3000;


    // calculate and set optimal column size
    var setColumnwidth = function() {
        var docwidth = $(document).width();
        var cwidth = 0;
        var columns = 0;
        // Decide on the best column width depending on docwidth
        // people with huge screens can tolerate more columns
        if (docwidth > 2500) 
            columns = 5;
        else if (docwidth > 1900) 
            columns = 4;
        else if (docwidth > 1000) 
            columns = 3;
        else if (docwidth >= 790)
            columns = 2;
        else if (docwidth < 790)
            columns = 1;

        // also subtract 3*columns, since every item got 6 px margin, 3 on each side
        cwidth = (docwidth / columns) - (4*columns); 
        $('.item').css('max-width', cwidth + 'px');
        $('.item img').css('width', cwidth + 'px');
        console.log('Decided on ', columns, ' columns with docwidth ', docwidth);
    }

    setColumnwidth();
    
    $container.imagesLoaded(function( $images, $proper, $broken ) {
        /*
        $container.isotope({
            itemSelector: '.item',
            resizable: false, // disable normal resizing
            animationEngine: 'css' // We want css, or no animation at all
        });
        */
        $('.item').wookmark({
            container: $('.items'),
            autoResize: false,
            offset: 6
        });

        // We are loaded, so hide the spinner
        $('.spinner').addClass('hidden');
    });
    
    $('.lb').click(function(e) {
        // Show spinner
        $('#spinner').removeClass('hidden');
        
        //prevent default action (hyperlink)
        e.preventDefault();
        
        //Get clicked link href
        var image_href = $(this).attr("href");

        // Save the current image
        currentimage = parseInt($(this).attr('id').split('-')[1]);
        
        
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
                '<p>' +
                '<a id="play" href="#"><i class="icon-play"></i></a>' +
                '<a id="goFS" href="#"><i class="icon-fullscreen"></i></a>' +
                '<a id="hideLB" href="#"><i class="icon-remove"></i></a></p>' +
                '<a href="#prev" id="prev"><div><i class="icon-chevron-left"></i></div></a>' +
                    '<div id="content">' + //insert clicked link's href into img src
                        '<img class="lbimg" id="img-front" src="' + image_href +'">' +
                    '</div>' +  
                '<a href="#next" id="next"><div><i class="icon-chevron-right"></i></div></a>' +
            '</div>';
                
            //insert lightbox HTML into page
            $('body').append(lightbox);

            // Run the set here to, to trigger click
            setLBimage(image_href);
        }


        // Handle clicks on the next link
        $('#next').bind('click', function(e) {
            pause(); play(); // Reset timer so we don't doubleskip
            $(document).trigger("next_image");
            return false;
        });
        // Handle clicks on the prev link
        $('#prev').bind('click', function(e) {
            pause(); play(); // Reset timer so we don't doubleskip
            $(document).trigger("prev_image");
            return false;
        });

        // Handle clicks on the fs link
        $('#goFS').bind('click', function(e) {
            e.preventDefault();
            goFS();
            return false;
        });

        // Handle clicks on the play link
        $('#play').bind('click', function(e) {
            if($('#play i').hasClass('icon-play')) {
                play();
            }else {
                pause();
            }
            e.preventDefault();
            return false;
        });

        // Handle all clicks in lb-mode
        $('#lightbox').bind('click', function(e) {
            var target = $(e.target);
            var id = target.attr('id');
            hideLB();
            return false;
        });

        showLB();

    });
    var setLBimage = function(image_href) {
        /* ANIM slideshow */
        if(slideshow) {

            $('#img-front').css('opacity', 0).bind("transitionend webkitTransitionEnd oTransitionEnd MSTransitionEnd", function(){ 
                $('#content').html('<img class="lbimg" id="img-front" src="' + image_href +'">');
                $('#img-front').css('opacity', 0.999).bind("transitionend webkitTransitionEnd oTransitionEnd MSTransitionEnd", function(){ 
                    $('#img-front').css('opacity', 1);
                });

            });
        }else {
            $('#img-front').attr('src', image_href);
        }

        // Count the viewing
        $.getJSON('/photongx/api/img/click/', { 'img':image_href}, function(data) {
            //console.log(data);
        });
        // TODO scrollto background pos img

    };
    var showLB = function() {
        $('#content').imagesLoaded(function( $images, $proper, $broken ) {
            // effects for background
            $('.items').addClass('backgrounded');
            //show lightbox window - you could use .show('fast') for a transition
            $('#lightbox').removeClass('hidden').show();
            // We are loaded, so hide the spinner
            $('.spinner').addClass('hidden');
            $('#img-front').css('opacity', 1);
        });
    };
        
    var hideLB = function() {
        if($('#goFS i').hasClass('icon-resize-small')) {
            document.cancelFullScreen();
        }
        // effects for background
        $('.items').removeClass('backgrounded');
        //$('#lightbox').hide();
        $('#lightbox').hide();
        // Stop any running slideshow;
        pause();
    };
    
    document.cancelFullScreen = document.webkitExitFullscreen || document.mozCancelFullScreen || document.exitFullscreen;
    
    var goFS = function(e) {
        if($('#goFS i').hasClass('icon-fullscreen')) {

            var elem = document.getElementById('lightbox');

            if (elem.requestFullScreen) {
                elem.requestFullScreen();
            } else if (elem.mozRequestFullScreen) {
                elem.mozRequestFullScreen();
            } else if (elem.webkitRequestFullScreen) {
                elem.webkitRequestFullScreen();
            }
            elem.onwebkitfullscreenchange = onFullScreenExit;
            elem.onmozfullscreenchange = onFullScreenExit;

            $('#goFS i').removeClass('icon-fullscreen').addClass('icon-resize-small');
        }else {
            document.cancelFullScreen();
            $('#goFS i').removeClass('icon-resize-small').addClass('icon-fullscreen');
        }
    }
    var onFullScreenExit = function() {
        console.log('onFSExit');
        //$('#goFS i').removeClass('icon-resize-small').addClass('icon-fullscreen');
    }
    

    // Slideshow
    var play = function() {
        $('#play i').removeClass('icon-play').addClass('icon-pause');
        slideshow = true;
        slideshowtimer = setInterval(function(){ $(document).trigger("next_image"); }, interval);
    }
    // Slideshow
    var pause = function() {
        $('#play i').removeClass('icon-pause').addClass('icon-play');
        slideshow = false;
        window.clearInterval(slideshowtimer);
    }

    // Function responsible for swapping the current lightbox image
    // it wraps on start and end, and preloads 3 images in the current 
    // scrolling direction
    var navigateImage = function(c) {
        if (c == 0) {
            // we are at the start, figure out the amount of items and
            // go to the end
            c = $('.item').length-1;
        }else if (c > ($('.item').length)) {
            c = 1; // Lua starts at 1 :)
        }
        var image_href = $('#image-'+c).attr('href');
        setLBimage(image_href);
        var cone = c+1, ctwo = c+2 , cthree = c+3;
        // We are going backwards
        if (c - currentimage) {
            cone = c-1, ctwo = c-2, cthree = c-3;
        }
        // Only load 1 image, faster swapping 
        $([
            $('#image-'+String(parseInt(cone))).attr('href'),
            ]).preload();

            //$('#image-'+String(parseInt(ctwo))).attr('href'),
            //$('#image-'+String(parseInt(cthree))).attr('href')
        currentimage = c;
    }

    $(document).on('next_image', function (evt) {
        navigateImage(currentimage + 1);
    });

    $(document).on('prev_image', function (evt) {
        navigateImage(currentimage - 1);
    });


    $(document).keydown(function(e){
      if (e.keyCode == 27) { 
          hideLB();
          return false;
      }
      else if (e.keyCode == 37 || e.keyCode == 39) {
          pause(); play(); // Reset timer so we don't doubleskip
          if (e.keyCode == 37) {
              $(document).trigger("prev_image");
          }
          else if (e.keyCode == 39) {
              $(document).trigger("next_image");
          }
          return false;
      }
      else if (e.keyCode == 70) {
          goFS();
      }
      else if (e.keyCode == 32) {
          $('#play').click();
      }
    });

});
