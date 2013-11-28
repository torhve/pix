var pnxapp = angular.module('PNXApp', ['PNXApp.services']);

pnxapp.controller('AlbumListCtrl', ['$scope', '$http', 'images', 'personaSvc', function($scope, $http, images, personaSvc) {
    $scope.images = images;
    $scope.selectedImages = [];
    $scope.selectedAlbum = false;
    $scope.hoverAlbum = false;
    $scope.verified = false;

    angular.extend($scope, { verified:false, error:false, email:"" });

    $scope.verify = function () {
        personaSvc.verify().then(function (email) {
            angular.extend($scope, { verified:true, error:false, email:email });
            $scope.status();
        }, function (err) {
            angular.extend($scope, { verified:false, error:err});
        });
    };

    $scope.logout = function () {
        personaSvc.logout().then(function () {
            angular.extend($scope, { verified:false, error:false});
        }, function (err) {
            $scope.error = err;
        });
    };

    $scope.status = function () {
        personaSvc.status().then(function (data) {
            // in addition to email, everything else returned by persona/status will be added to the scope
            // this could be the chance to expose data from your local DB, for example
            angular.extend($scope, data, { error:false, verified:!!data.email, email:data.email });
            // if we are verified refresh the item list
            // basicially means we just logged in
            if ($scope.verified) {
                $scope.init();
            }                                                                                                                                               
        }, function (err) {
            $scope.error = err;
        });
    };

    // setup; check status once on init
    $scope.status();

    // Init function gets called from status function when user logs in
    $scope.init = function() {
        $('.spinner').removeClass('hidden');
        //images.getImagesFromBackend();

        images.getAlbumsFromBackend();
        images.getQueueCount();
        // Update queue count on a timer
        var timer = setInterval(function() {
            images.getQueueCount();
            $scope.$apply();
        }, 6000);
    }
    /* Fired after everything has been loaded from the backend */
    $scope.$watch('images.images', function() {
        $('.spinner').addClass('hidden');
        // TODO this should be more clever
        setTimeout(function() {
            $('.aitems').imagesLoaded(function( $images, $proper, $broken ) {
                apnx = photongx($('.aitems'), $('.aitem'));
            });
        }, 2000);
    });
    $scope.$watch('images.albums', function() {
        $('.spinner').addClass('hidden');
    });
    
    /* Rewookmark when filter expression changes */
    $scope.$watch('albumsearch', function() {
        setTimeout(function() {
            $('.aitems').imagesLoaded(function( $images, $proper, $broken ) {
                apnx = photongx($('.aitems'), $('.aitem'));
            });
        });
    });



    $scope.mouseOverAlbum = function(album) {
        $scope.hoverAlbum = album.title;
    }

    $scope.clickAlbum = function(album) { 
       images.getImagesFromBackend(album);
       $scope.uploading = false;
       $scope.selectedAlbum = album.title;
        // Scroll top top, since we might be far down in the navigaiton list
        $("body").scrollTop(0);
       // TODO make this clever?
       setTimeout(function() {
           pnx = photongx($('.items'), $('.item'));
        }, 2000);
    }

    $scope.albumModify = function(album) {
        console.log($scope.selectedAlbum, album, $scope.albumtitle, album.title);
        $('#albumtitlemodal').modal('show');
        $scope.album = album;
    }

    $scope.submitNewAlbum = function() {
        $scope.uploading = true;
        $scope.selectedAlbum = false;
        var album = $scope.albumname;

        // Create album
        $http.post('/api/albums', {name:album}).then(function(data) {
            // Refresh album list from backend
            images.getAlbumsFromBackend();
            var tag = data.data.album.token;

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
        $('#input-album-id').val(album.id);
        $('#albumlinkmodal').modal('show');
        return false;
    }
    $scope.albumAdd = function(album) {
        $scope.uploading = true;
        $scope.selectedAlbum = false;
        $scope.albumname = album.title;
        $scope.submitNewAlbum();
        return false;
    }
    $scope.submitAlbumLink = function() {
        var formData = $('#form-ttl').serialize();
        var formUrl = "/api/albumttl/"+$('#input-album-id').val();
        $http.post(formUrl, formData).then(function(data) { 
            console.log(data);
            $scope.linkAlbum = '';
            $('#albumlinkmodal').modal('hide');
        });
    }
    $scope.submitAlbumTitle = function () {
        $('#albumtitlemodal').modal('hide');
        $http.put('/api/albums/'+$scope.album.id, $scope.album).then(function(data) {
            console.log(data);
            images.getAlbumsFromBackend();
        });
    }
}]);


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
        images: [],
        imagecount: {},
        accesskeys: {},
        accesskeysh: {},
        nrofimages: 0,
        thumbs: {},
        imagesarray: {},
        tags: {},
        queueCount: 0,
        getAlbumsFromBackend: function() {
            $http.get('/api/albums').then(function(data) {
                images.albums = data.data.albums;
            });
        },
        getImagesFromBackend: function(album) {
            $http.get('/api/images/'+album.id).then(function(data) {
                images.images = data.data.images;
            });
        },
        getQueueCount: function() {
            $http.get('/api/queue').then(function(data) {
                var counter =  data.data['counter'];
                images.queueCount = counter;
            });
        }
    }
    return images;
}]);

services.factory("personaSvc", ["$http", "$q", function ($http, $q) {

  return {
        verify:function () {
            var deferred = $q.defer();
            navigator.id.get(function (assertion) {
                $http.post("/api/persona/login", {assertion:assertion})
                    .then(function (response) {
                        if (response.data.status != "okay") {
                            deferred.reject(response.data.reason);
                        } else {
                            deferred.resolve(response.data.email);
                        }
                    });
            });
            return deferred.promise;
        },
        logout:function () {
            return $http.post("/api/persona/logout").then(function (response) {
                if (response.data.status != "okay") {
                    $q.reject(response.data.reason);
                }
                return response.data.email;
            });
        },
        status:function () {
            return $http.post("/api/persona/status").then(function (response) {
                return response.data;
            });
        }
    };
}]);

//AlbumListCtrl.$inject = ["$scope", "personaSvc"];



var pnxadmin = (function() {

    // When you click the modify link in the navigation
    $('.albummodify').bind('click', function() {
        console.log(this, 'clicked');
        var albumname = $(this).attr('id').split('/')[1];
        console.log(albumname, 'clicked');

        $('#admincontent .adminalbum').prependTo($('#albumcontainer').toggleClass('hidden'));
        $('#admincontent').html('');
        $('#album-'+albumname).toggleClass('hidden').prependTo($('#admincontent'));



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

    return this;
});


