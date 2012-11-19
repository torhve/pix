var pnxadmin = (function() {
    var updateQueueCount = function() {
        $.getJSON(BASE + 'admin/api/queue/length/', function(data) {
            $('#li-queue span').html(data['counter']);
        });
    }
    setInterval(updateQueueCount, 6000);


    // When you click the modify link in the navigation
    $('.albummodify').bind('click', function() {
        console.log(this, 'clicked');
        var albumname = $(this).attr('id').split('/')[1];
        console.log(albumname, 'clicked');

        $('#admincontent .adminalbum').prependTo($('#albumcontainer').toggleClass('hidden'));
        $('#admincontent').html('');
        $('#album-'+albumname).toggleClass('hidden').prependTo($('#admincontent'));
        $('#admincontent .adminthumb').each(function(i, img) {
            var img = $(img);
            img.attr('src', img.attr('_src'));
        });

        // Scroll top top, since we might be far down in the navigaiton list
        $("body").scrollTop(0);


        $('#admincontent').imagesLoaded(function() {
            $('.item').wookmark({
                container: $('#admincontent .items'),
                autoResize: true,
                offset: 3
            });
        });
        return false;
    });

    $('.li-nav-album').hover(
        function() {
            $(this).find('.btn-group').removeClass('hidden');
        },
        function() {
            $(this).find('.btn-group').addClass('hidden');
        }
    );

    $('.albumtemp').bind('click', function() {
        console.log(this, 'temp clicked');
        var albumname = $(this).attr('id').split('/')[1];
        console.log(albumname, 'clicked');
        $('#input-album-name').val(albumname);
        $('.modal').modal('show');
        return false;
    });

    $('#form-ttl').submit(function(ev) {
        ev.stopPropagation();
        ev.preventDefault();
        var formData = $(this).serialize();
        //var formUrl = BASE+"admin/api/albumttl/create/";
        var formUrl = "/admin/api/albumttl/create/";
        $.getJSON(formUrl, formData, function(data) { 
            console.log(data);
            $('.modal').modal('hide');
        });
        return false;
    });

    $('.link-image-remove').bind('click', function(ev) {
        console.log(this, 'clicked');
        ev.stopPropagation();
        ev.preventDefault();
        // CALL API
        $.getJSON($(this).attr('href'), function(data) { 
            if(data) {
                $(this).closest('.item').remove();
            }
            console.log(data); 
        });
        return false;
    });

    $('.uploadform').submit(function(ev) {
        ev.stopPropagation();
        ev.preventDefault();
        album = $('#albumname').val();
        $('.uploadcontainer').clone().prependTo($('#admincontent')).toggleClass('hidden');
        $('<h1>Upload<small>to album <a href="'+BASE+tag+'/'+album+'/">'+album+'</a></h1>').prependTo($('#admincontent .hero-unit'));
        if (typeof FileReader == "undefined") alert ("Your browser is not supported. You will need to update to a modern browser with File API support to upload files.");
        var fileList = document.getElementById("fileList");
        var fileDrop = document.getElementById("fileDrop");
        var fileField = document.getElementById("fileField");
        FileAPI = new FileAPI(
            fileList,
            fileDrop,
            fileField
            );
        FileAPI.init();

        // Automatically start upload when using the drop zone
        fileDrop.ondrop = FileAPI.uploadQueue;
        //fileField.onkeypress = FileAPI.uploadQueue;

        var reset = document.getElementById("reset");
        reset.onclick = FileAPI.clearList;
        var upload = document.getElementById("upload");
        upload.onclick = FileAPI.uploadQueue;
    });

    var FileAPI = function (t, d, f) {

        var fileList = t,
            dropZone = d,
            fileField = f,
            fileQueue = new Array()
                preview = null;


        this.init = function () {
            fileField.onchange = this.addFiles;
            dropZone.addEventListener("dragenter",  this.stopProp, false);
            dropZone.addEventListener("dragleave",  this.dragExit, false);
            dropZone.addEventListener("dragover",  this.dragOver, false);
            dropZone.addEventListener("drop",  this.showDroppedFiles, false);
        }

        this.addFiles = function () {
            addFileListItems(this.files);
        }

        this.showDroppedFiles = function (ev) {
            ev.stopPropagation();
            ev.preventDefault();

            dropZone.style["backgroundColor"] = "#d9edf7";
            dropZone.style["borderColor"] = "#bce8f1";
            dropZone.style["color"] = "#3a87ad";

            var files = ev.dataTransfer.files;
            addFileListItems(files);
        }

        this.clearList = function (ev) {
            ev.preventDefault();
            while (fileList.childNodes.length > 0) {
                fileList.removeChild(
                        fileList.childNodes[fileList.childNodes.length - 1]
                        );
            }
        }

        this.dragOver = function (ev) {
            ev.stopPropagation();
            ev.preventDefault();
            this.style["backgroundColor"] = "#f2dede";
            this.style["borderColor"] = "#eed3d7";
            this.style["color"] = "#b94a48";
        }

        this.dragExit = function (ev) {
            ev.stopPropagation();
            ev.preventDefault();
            dropZone.style["backgroundColor"] = "#d9edf7";
            dropZone.style["borderColor"] = "#bce8f1";
            dropZone.style["color"] = "#3a87ad";
        }

        this.stopProp = function (ev) {
            ev.stopPropagation();
            ev.preventDefault();
        }

        this.uploadQueue = function (ev) {
            ev.preventDefault();
            while (fileQueue.length > 0) {
                var item = fileQueue.shift();
                var p = document.createElement("p");
                p.className = "loader";
                var pText = document.createTextNode("Pending...");
                p.appendChild(pText);
                item.li.appendChild(p);
                if (item.file.size < 32212254720) {
                    p.style["color"] = "#3a87ad";
                    uploadFile(item.file, item.li);
                } else {
                    p.textContent = "File to large (>30GB)";
                    p.style["color"] = "red";
                }
            }
        }

        var addFileListItems = function (files) {
            for (var i = 0; i < files.length; i++) {
                //var fr = new FileReader();
                //fr.file = files[i];
                //fr.onloadend = showFileInList;
                showFileInList(files[i])
                    //fr.readAsDataURL(files[i]);
            }
        }

        var showFileInList = function (file) {
            //var file = ev.target.file;
            if (file) {
                var li = document.createElement("li");
                var h5 = document.createElement("h5");
                var h5Text = document.createTextNode(file.name);
                h5.appendChild(h5Text);
                li.appendChild(h5)
                    var p = document.createElement("p");
                var pText = document.createTextNode(
                        "File type: "
                        + file.type + ", size: " +
                        Math.round(file.size / 1024 / 1024) + " MB"
                        );
                p.appendChild(pText);
                li.appendChild(p);
                var divContainer = document.createElement("div");
                divContainer.className = "progress progress-striped active";
                var divLoader = document.createElement("div");
                divLoader.className = "bar";
                li.appendChild(divContainer);
                divContainer.appendChild(divLoader);
                fileList.appendChild(li);
                fileQueue.push({
                    file : file,
                    li : li
                });
            }
        }

        function roundNumber(num, dec) {
            var result = Math.round(num*Math.pow(10,dec))/Math.pow(10,dec);
            return result;
        }

        var uploadFile = function (file, li) {
            if (li && file) {
                var xhr = new XMLHttpRequest(),
                    upload = xhr.upload;
                upload.addEventListener("progress", function (ev) {
                    if (ev.lengthComputable) {
                        var loader = li.getElementsByTagName("div")[1];
                        loader.style["width"] = (ev.loaded / ev.total) * 100 + "%";
                        var ps = li.getElementsByTagName("p");
                        for (var i = 0; i < ps.length; i++) {
                            if (ps[i].className == "loader") {
                                var percent = (ev.loaded / ev.total) * 100;
                                ps[i].textContent = "Uploading... " + percent.toFixed(2) + "%";
                                ps[i].style["color"] = "#c09853";
                                break;
                            }
                        }
                    }
                }, false);
                upload.addEventListener("load", function (ev) {
                    var ps = li.getElementsByTagName("p");
                    var div = li.getElementsByTagName("div")[1];
                    div.style["width"] = "100%";
                    div.style["backgroundColor"] = "#468847";
                    for (var i = 0; i < ps.length; i++) {
                        if (ps[i].className == "loader") {
                            ps[i].textContent = "Upload complete";
                            ps[i].style["color"] = "white";
                            break;
                        }
                    }
                }, false);
                upload.addEventListener("error", function (ev) {console.log(ev);}, false);
                xhr.open(
                        "POST",
                        BASE + 'upload/post/'
                        );
                xhr.setRequestHeader("Cache-Control", "no-cache");
                xhr.setRequestHeader("X-Requested-With", "XMLHttpRequest");
                xhr.setRequestHeader("X-File-Name", file.name);
                xhr.setRequestHeader("X-Album", album);
                xhr.setRequestHeader("X-Tag", tag);
                xhr.setRequestHeader("Content-MD5", calcMD5(file));
                xhr.send(file);
            }
        }

    }
  

    $('#fileSelect-show').bind('click', function() {
        $('#fileSelect').toggleClass('hidden');
        return false;
    });
    $('#fileSelect-hide').bind('click', function() {
        $('#fileSelect').toggleClass('hidden');
        return false;
    });

    return this;
});
