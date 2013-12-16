var photongx = (function($container, $items) {
    var slideshow = false,
        currentimage = parseInt(window.location.hash.replace('#', ''), 10) || -1,
        slideshowtimer,
        slideinterval = 4000,
        offset = 4,
        startPos, 
        endPos, 
        lastPos;

    // If lightbox already exists it means that photngx was called
    // multiple times on the same page
    // In that case we remove the lightbox, since the lightbox contains
    // bindings that would trigger multiple times if not
    var lb = document.getElementById('lightbox');
    if(lb != null) {
        // Lightbox should always be a child of body
        document.body.removeChild(lb);
    }
    // We also need to unbind our previously registered event handlers
    // or they would all trigger multiple times
    $(document).off('next_image prev_image keydown debouncedresize');

    // Image preloading function
    $.fn.preload = function() {
        this.each(function(){
            // Check if url starts with /
            if (this[0] == '/') {
                $('<img>')[0].src = this;
            }
        });
    }
    $(window).on("debouncedresize", function(event) {
        setColumnwidth();
        $container.trigger('refreshWookmark');
    });

    // calculate and set optimal column size
    this.setColumnwidth = function() {
        var docwidth = document.body.clientWidth;
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

        // also subtract columns*offsett, since every item got offset px margin, offset/2 on each side
        cwidth = docwidth / columns - (offset*(columns-1)); 
        //$('.item').css('max-width', cwidth + 'px');
        $items.find('img').css('width', cwidth + 'px');
        //console.log('Decided on ', columns, ' columns with docwidth ', docwidth);
    }
    setColumnwidth();

    this.wookmarkIt = function() {
        setColumnwidth();
        $items.wookmark({
            container: $container,
            autoResize: false,
            flexibleWidth: false,
            outerOffset: 0,
            align: 'left',
            offset: offset
        });
    }

    
    $container.imagesLoaded(function( $images, $proper, $broken ) {
        //setColumnwidth();

        wookmarkIt();

        // We are loaded, so hide the spinner
        $('.spinner').addClass('hidden');
    });

    // We got a new browser state from pressing prev or next buttons
    /*
    window.addEventListener("popstate", function (evt) {
        if (evt.state && evt.state.image) {
            navigateImage(evt.state.image);
        }
        else {
            // Assume we got an url that doesn't show an image
            hideLB();
        }
    });
    */
    
    $('.lb').click(function(e) {
        // Show spinner
        $('#spinner').removeClass('hidden');
        
        //prevent default action (hyperlink)
        e.preventDefault();

        createLB();
        
        //Get clicked link href
        //var image_href = $(this).attr("href");

        // Save the current image
        currentimage = $items.index($(this).parent()); 
        
        navigateImage(currentimage);

        //showLB();

        // Push inn <albumurl>/<image_id>/ to history
        // FIXME history.pushState({ image: currentimage }, null, window.location.href + currentimage + "/");
        
        /*  
        If the lightbox window HTML already exists in document, 
        change the img src to to match the href of whatever link was clicked
        
        If the lightbox window HTML doesn't exists, create it and insert it.
        (This will only happen the first time around)
        */
        /*
        createLB();

        setLBimage(image_href);
        countView($(this).attr('id'));
        */

        //showLB();
    });

    this.createLB = function() {
        if ($('#lightbox').length == 0) { // #lightbox does not exist
            //create HTML markup for lightbox window
            var lightbox = 
            '<div id="lightbox" style="display:none">' +
                '<div class="action-group">' +
                '<a id="play" href="#" title="Toggle slideshow"><i class="fa fa-play"></i></a>' +
                '<a id="goFS" href="#" title="Toggle full screen"><i class="fa fa-arrows-alt"></i></a>' +
                '<a id="hideLB" href="#" title="Close image"><i class="fa fa-times"></i></a></div>' +
                '<a href="#prev" id="prev" title="Previous image"><div><i class="fa fa-backward"></i></div></a>' +
                    '<div id="lbcontent">' + //insert clicked link's href into img src
                        '<img class="lbimg" id="img-front">' +
                    '</div>' +  
                '<a href="#next" id="next" title="Next image"><div><i class="fa fa-forward"></i></div></a>' +
            '</div>';

            //var svg_image_blur = '<svg><filter id="blur-effect-1"><feGaussianBlur stdDeviation="2"/></filter></svg>'
            // insert svg image blur
            //$('body').append(svg_image_blur);
                
            // insert lightbox HTML into page
            $('body').append(lightbox);

            // Run the set here to, to trigger click
            $('#next').bind('click', function(e) {
                // Reset timer so we don't doubleskip
                if (slideshow) {
                    pause(); 
                    play(); 
                }
                $(document).trigger("next_image");
                return false;
            });
            // Handle clicks on the prev link
            $('#prev').bind('click', function(e) {
                if (slideshow) {
                    // Reset timer so we don't doubleskip
                    pause();
                    play(); 
                }
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
                if($('#play i').hasClass('fa-play')) {
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
            // Handle touch events in lb-mode
            $('#lightbox').bind('touchstart touchmove touchend', function(ev) {
                var e = ev.originalEvent;
                if(e.type == 'touchstart') {
                    //record the start clientX
                    startPos = e.touches[0].clientX;

                    //lastPos is startPos at the beginning
                    lastPos = startPos;

                    //we'll keep track of direction as a signed integer.
                    // -1 is left, 1 is right and 0 is staying still
                    direction = 0;
                }
                else if(e.type == 'touchmove' ) {
                    e.preventDefault();

                    //figure out the direction
                    if(lastPos > startPos){
                        direction = -1;
                    }else{
                        direction = 1;
                    }
                    //save the last position, we need it for touch end
                    lastPos = e.touches[0].clientX;
                }
                else if(e.type == 'touchend'){
                    //figure out if we have moved left or right beyond a threshold
                    //(50 pixels in this case)
                    if(lastPos - startPos > 50){
                        $(document).trigger("prev_image");
                    } else if(lastPos - startPos < -50){
                        $(document).trigger("next_image");
                    }else{
                        //we are not advancing
                    }
                }

                return false;
            });
        }
    }

    var setLBimage = function(image_href) {

        var swapsrc = function(image_href) {
            var imgfront = document.getElementById('img-front');
            // Save the old src so we can compare it to the new one, since the new vs old can use relative vs absolute URL.
            var oldsrc = imgfront.src;
            imgfront.src = image_href;
            var newsrc = imgfront.src;
            // The onload event will not fire if the src does not change so we check for this condition
            if (oldsrc == newsrc) {
                showLB();
            }else {
                if(slideshow) {
                    imgfront.onload = function() {
                        $('#img-front').css('opacity', 0.999).one("transitionend webkitTransitionEnd oTransitionEnd MSTransitionEnd", function(){ 
                            $('#img-front').css('opacity', 1);
                        });
                    }
                }
                else {
                    imgfront.onload = function() { showLB(); }; 
                }
            }
        }
        /* ANIM slideshow */
        if(slideshow) {
            $('#img-front').css('opacity', 0).one("transitionend webkitTransitionEnd oTransitionEnd MSTransitionEnd", function(){ 
                swapsrc(image_href);
            });
        }else {
            swapsrc(image_href);
        }
    };
    this.showLB = function() {
        $('#lbcontent').imagesLoaded(function( $images, $proper, $broken ) {
            // effects for background
            $container.addClass('backgrounded');
            // We are loaded, so hide the spinner
            $('.spinner').addClass('hidden');
            //show lightbox window - you could use .show('fast') for a transition
            $('#lightbox').show();
            $('#img-front').css('opacity', 1);
        });
    };
        
    var hideLB = function() {
        if($('#goFS i').hasClass('fa fa-compress')) {
            document.cancelFullScreen();
        }
        // effects for background
        $container.removeClass('backgrounded');
        //$('#lightbox').hide();
        $('#lightbox').hide();
        // Stop any running slideshow;
        pause();

        // Push away image number path
        /*
        var base_parts = window.location.href.split("/");
        if (base_parts[base_parts.length-2] == currentimage) {
            base = base_parts.slice(0, base_parts.length - 2).join("/") + "/";
            // FIXME history.pushState({ image: null }, null, base);
        }
        */

        // Remove hash (and scroll to the current image)
        var link = $($items[currentimage]).find('a');
        window.location.hash = link.attr('id');
    };
    
    document.cancelFullScreen = document.webkitExitFullscreen || document.mozCancelFullScreen || document.exitFullscreen;
    
    var goFS = function(e) {
        if($('#goFS i').hasClass('fa-arrows-alt')) {

            var elem = document.getElementById('lightbox');

            if (elem.requestFullScreen) {
                elem.requestFullScreen();
            } else if (elem.mozRequestFullScreen) {
                elem.mozRequestFullScreen();
            } else if (elem.webkitRequestFullScreen) {
                elem.webkitRequestFullScreen();
            } else if (elem.msRequestFullscreen) {
                elem.msRequestFullScreen();
            }
            elem.onwebkitfullscreenchange = onFullScreenExit;
            elem.onmozfullscreenchange = onFullScreenExit;

            $('#goFS i').removeClass('fa-arrows-alt').addClass('fa-compress');
        }else {
            document.cancelFullScreen();
            $('#goFS i').removeClass('fa-compress').addClass('fa-arrows-alt');
        }
    }
    var onFullScreenExit = function() {
        console.log('onFSExit');
    }
    

    // Slideshow
    var play = function() {
        $('#play i').removeClass('fa-play').addClass('fa-pause');
        slideshow = true;
        slideshowtimer = setInterval(function(){ $(document).trigger("next_image"); }, slideinterval);
    }
    // Slideshow
    var pause = function() {
        $('#play i').removeClass('fa-pause').addClass('fa-play');
        slideshow = false;
        window.clearInterval(slideshowtimer);
    }

    // Clamp skip to images available
    var clampSkip = function (c) {
        if (c < 0) {
            // we are at the start, figure out the amount of items and
            // go to the end
            c = $items.length - 1 ;
        }else if (c > ($items.length-1)) {
            c = 0; 
        }

        return c;
    }
    // Function responsible for swapping the current lightbox image
    // it wraps on start and end, and preloads 3 images in the current 
    // scrolling direction
    this.navigateImage = function(c) {
        var link = $($items[c]).find('a');
        var image_href = link.attr('href');
        setLBimage(image_href);
        countView(link.attr('id'));

        var cone = c+1, ctwo = c+2 , cthree = c+3;
        // We are going backwards
        if (c - currentimage) {
            cone = c-1, ctwo = c-2, cthree = c-3;
        }
        // Only load 1 image, faster swapping 
        $([
            $($items[parseInt(cone)]).find('a').attr('href'),
          ]).preload();

            //$('#image-'+String(parseInt(ctwo))).attr('href'),
            //$('#image-'+String(parseInt(cthree))).attr('href')
        currentimage = c;

        // Update hash
        window.location.hash = '#' + c;
    }

    //
    // Function responsible for counting clicks/views in the backend
    // It uses the HTML id of the image which the backend uses to increment the view
    // counter of the correct image
    //
    this.countView = function(file_name) {
        if (file_name == undefined || file_name == '') return;
        $.getJSON('/api/img/click', { 'img':file_name}, function(data) {
            if (!data.views > 0) {
                console.log('Error counting clicks. Response from backend was',data);
            }
        });
    }

    $(document).on('next_image', function (evt) {
        // Get image number corrected for skipping passed last image
        var image_num = clampSkip(currentimage+1);

        // Cut out the image number we are at and replace with next image
        var base_parts = window.location.href.split("/");
        if (base_parts[base_parts.length-2] == currentimage)
            base = base_parts.slice(0, base_parts.length - 2).join("/") + "/";
        else
            base = window.location.href;

        // Push new url for to history for the image we are about to display
        // FIXME history.pushState({ image: image_num }, null, base + image_num + "/");
        navigateImage(image_num);
    });

    $(document).on('prev_image', function (evt) {
        // Get image number corrected for skipping passed first image
        var image_num = clampSkip(currentimage - 1);
        
        // Cut out the image number we are at and replace with next image
        var base_parts = window.location.href.split("/");
        if (base_parts[base_parts.length-2] == currentimage)
            base = base_parts.slice(0, base_parts.length - 2).join("/") + "/";
        else
            base = window.location.href;
    
        // Push new url for to history for the image we are about to display
        // FIXME history.pushState({ image: image_num }, null, base + image_num + "/");
        navigateImage(image_num);
    });

    $(document).keydown(function(e){
        if (e.shiftKey || e.altKey || e.ctrlKey || e.metaKey ) return true;
        // Don't do anything if lightbox isn't there
        if (!document.getElementById('lightbox')) return true;
        // Don't do anything if lightbox isn't visible
        if (document.getElementById('lightbox').style.display == 'none') return true;

        if (e.keyCode == 27) { 
            hideLB();
            return false;
        }
        else if (e.keyCode == 37 || e.keyCode == 39) {
            if (slideshow) {
                // Reset timer so we don't doubleskip
                pause(); 
                play(); 
            }
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


    // If currentImage is set, create lightbox and navigate to it
    if(currentimage > -1) {
        createLB();
        navigateImage(currentimage);
        showLB();
    }

    return this;
});
