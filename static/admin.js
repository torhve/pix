var pnxapp = angular.module('PNXApp', ['PNXApp.services']);
function AlbumListCtrl($scope, $http, images) {
    $scope.selectedImages = [];

    images.getAllFromBackend();
    images.getImagesFromBackend();
    $scope.images = images;
    console.log($scope.images);

    images.getQueueCount();
    // Update queue count on a timer
    var timer = setInterval(function() {
        images.getQueueCount();
        $scope.$apply();
    }, 6000);

    $scope.selectedAlbum = false;
    $scope.hoverAlbum = false;

    $scope.mouseOverAlbum = function(album) {
        $scope.hoverAlbum = album;
    }

    $scope.clickAlbum = function(album) { 
       $scope.uploading = false;
       $scope.selectedAlbum = album;
       // TODO make this clever?
       setTimeout(function() {
           $('#admincontent').imagesLoaded(function() {
               $('.item').wookmark({
                   container: $('#admincontent .items'),
                   autoResize: true,
                   offset: 3
               });
           });
        }, 2000);

    }

    $scope.submitNewAlbum = function(ev) {
        $scope.uploading = true;
        $scope.selectedAlbum = false;
        var album = $scope.albumname;

        // Get tag from backend
        $http.get('/admin/api/gentag/').then(function(data) {
            var tag = data.data.tag;

            //$('<h1>Upload<small>to album <a href="/album/'+tag+'/'+album+'/">'+album+'</a></h1>').prependTo($('#admincontent .hero-unit'));
            if (typeof FileReader == "undefined") alert ("Your browser is not supported. You will need to update to a modern browser with File API support to upload files.");
            var fileCount = document.getElementById("fileCount");
            var fileList = document.getElementById("fileList");
            var fileDrop = document.getElementById("fileDrop");
            var fileField = document.getElementById("fileField");
            FileAPI = new FileAPI(
                fileCount,
                fileList,
                fileDrop,
                fileField,
                tag,
                album
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
    }
    $scope.albumLink = function(album) {
        $('#input-album-name').val(album);
        $('.modal').modal('show');
        return false;
    }
    $scope.submitAlbumLink = function() {
        var formData = $('#form-ttl').serialize();
        var formUrl = "/admin/api/albumttl/create/";
        console.log($scope.linkAlbum);
        $.getJSON(formUrl, formData, function(data) { 
            console.log(data);
            $scope.linkAlbum = '';
            $('.modal').modal('hide');
        });
    };
}


function PImage(entry) {
    // TODO, set thumb-name to orig name if not set
    angular.extend(this, entry);
}
PImage.prototype.$$hashKey = function() {
  return this.id;
}



var services = angular.module('PNXApp.services', []);


services.factory('images', ['$http', function($http) {
    var images = {
        all: {},
        albums: [],
        imagecount: {},
        accesskeys: {},
        accesskeysh: {},
        nrofimages: 0,
        thumbs: {},
        tags: {},
        queueCount: 0,
        getAllFromBackend: function() {
            $http.get('/admin/api/all/').then(function(data) {
              var res = data.data;
              images.albums = res.albums;
              images.tags = res.tags;
              images.thumbs = res.thumbs;
              images.accesskeysh = res.accesskeysh;
              images.accesskeys = res.accesskeys;
            });
        },
        getImagesFromBackend: function() {
            $http.get('/admin/api/images/').then(function(data) {
                var i = 0;
                angular.forEach(data.data, function(entry, id) {
                    var pimage = new PImage(entry); 
                    if(images.imagecount[entry.album] == undefined) {
                        images.imagecount[entry.album] = 1;
                    }else{
                        images.imagecount[entry.album]++;
                    }
                    images.all[id] = pimage;
                    i++;
                })
                images.nrofimages = i;
            });
        },
        getQueueCount: function() {
            $http.get('/admin/api/queue/length/').then(function(data) {
                var counter =  data.data['counter'];
                images.queueCount = counter;
            });
        }
    }
    return images;
}]);




var pnxadmin = (function() {

    // When you click the modify link in the navigation
    $('.albummodify').bind('click', function() {
        console.log(this, 'clicked');
        var albumname = $(this).attr('id').split('/')[1];
        console.log(albumname, 'clicked');

        $('#admincontent .adminalbum').prependTo($('#albumcontainer').toggleClass('hidden'));
        $('#admincontent').html('');
        $('#album-'+albumname).toggleClass('hidden').prependTo($('#admincontent'));

        // Scroll top top, since we might be far down in the navigaiton list
        $("body").scrollTop(0);


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


