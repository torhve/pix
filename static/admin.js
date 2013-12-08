var pnxapp = angular.module('PNXApp', ['PNXApp.services']);

pnxapp.filter('startFrom', function() {
    return function(input, start) {
        start = +start; //parse to int
        return input.slice(start);
    }
});


pnxapp.controller('AlbumListCtrl', ['$rootScope', '$scope', '$http', '$filter', 'images', 'personaSvc', function($rootScope, $scope, $http, $filter, images, personaSvc) {
    $scope.images = images;
    $scope.selectedImages = [];
    $scope.selectedAlbum = false;
    $scope.hoverAlbum = false;
    $scope.verified = false;
    $scope.imageinfo = false;

    $scope.currentPage = 0;
    $scope.pageSize = 50;
    $scope.numberOfPages = function() {
        return Math.ceil(images.photostreamimages.length/$scope.pageSize);
    }

    if (typeof FileReader == "undefined") {
        alert ("Your browser is not supported. You will need to update to a modern browser with File API support to upload files.");
    }
    var fileCount = document.getElementById("fileCount");
    var fileList = document.getElementById("fileList");
    var fileDrop = document.getElementById("fileDrop");
    var fileField = document.getElementById("fileField");
    var fa = new FileAPI(
        fileCount,
        fileList,
        fileDrop,
        fileField
        );
    fa.init();

    // Automatically start upload when using the drop zone
    fileDrop.ondrop = fa.uploadQueue;

    var reset = document.getElementById("reset");
    reset.onclick = fa.clearList;
    var upload = document.getElementById("upload");
    upload.onclick = fa.uploadQueue;

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
        //images.getImagesFromBackend();
        $rootScope.$emit('spin');

        images.getAlbumsFromBackend();
        images.getQueueCount();
        // Update queue count on a timer
        var timer = setInterval(function() {
            images.getQueueCount();
            $scope.$apply();
        }, 6000);
    }


    // Spinner start event
    $rootScope.$on('spin', function() {
        $('.spinner').removeClass('hidden');
    });

    // Spinner end event
    $rootScope.$on('spun', function() {
        $('.spinner').addClass('hidden');
    });


    /* Fired after photostream navigation */
    $scope.$watch('currentPage', function(current, previous, scope) {
        $rootScope.$emit('spin');
        $('.items').imagesLoaded(function( $images, $proper, $broken ) {
            apnx = photongx($('.items'), $('.item'));
            $rootScope.$emit('spun');
        });
    });

    $scope.$watch('images.albums', function() {
        $rootScope.$emit('spun');
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
    $scope.mouseOverAlbumClear = function() {
        $scope.hoverAlbum = false;
    }

    $scope.clickAlbum = function(album) { 
        $rootScope.$emit('spin');
        images.getAccestokensFromBackend(album);
        images.getImagesFromBackend(album);
        $scope.uploading = false;
        $scope.selectedAlbum = album;
        images.photostreamimages = [];
        // Scroll top top, since we might be far down in the navigaiton list
        $("body").scrollTop(0);
    }
    $rootScope.$on('imagesLoaded', function() {
        // TODO make this clever?
       setTimeout(function() {
           $('.items').imagesLoaded(function( $images, $proper, $broken ) {
               apnx = photongx($('.items'), $('.item'));
               $rootScope.$emit('spun');
           });
        });
    });

    $scope.clickPhotoStream = function() {
       $rootScope.$emit('spin');
       $scope.uploading = false;
       $scope.selectedAlbum = false;
       images.photostreamimages = [];
       images.getPhotoStreamFromBackend();
    }
    $rootScope.$on('photostreamLoaded', function() {
       setTimeout(function() {
           $('.items').imagesLoaded(function( $images, $proper, $broken ) {
               apnx = photongx($('.items'), $('.item'));
               $rootScope.$emit('spun');
           });
        });
    });

    $scope.albumModify = function(album) {
        $('#albumtitlemodal').modal('show');
        $scope.album = album;
    }

    $scope.submitNewAlbum = function() {
        $scope.uploading = true;
        $scope.selectedAlbum = false;
        $scope.photostreamimages = [];
        var album = $scope.albumname;

        // Create album
        $http.post('/api/albums', {name:album}).then(function(data) {
            // Refresh album list from backend
            images.getAlbumsFromBackend();
            var album = data.data.album;
            fa.setAlbum(album);
            fa.clearList();
        });
    }
    $scope.albumLink = function(album) {
        $scope.linkalbum = album;
        $('#input-album-id').val(album.id);
        $('#albumlinkmodal').modal('show');
        return false;
    }
    $scope.albumAdd = function(album) {
        $scope.uploading = true;
        $scope.selectedAlbum = false;
        $scope.albumname = album.title;
        fa.setAlbum(album);
        $scope.submitNewAlbum();
        return false;
    }
    $scope.submitAlbumLink = function() {
        var formData = $('#form-ttl').serialize();
        var formUrl = "/api/albumttl/"+$('#input-album-id').val();
        $http.post(formUrl, formData).then(function(data) { 
            $('#albumlinkmodal').modal('hide');
            images.getAccestokensFromBackend($scope.linkalbum);
            $scope.linkalbum = "";
        });
    }
    $scope.submitAlbumTitle = function () {
        $('#albumtitlemodal').modal('hide');
        $http.put('/api/albums/'+$scope.album.id, $scope.album).then(function(data) {
            console.log(data);
            images.getAlbumsFromBackend();
        });
    }
    $scope.imageRemove = function(image) {
        $http.delete('/api/image/'+image.id).then(function(data) {
            if (data.status == 200) {
                images.images.splice(images.images.indexOf(image), 1);
            }else {
                $scope.error = data.data;
            }
        });
    }
    $scope.albumRemove = function(album) {
        $scope.albumremove = album;
        $('#albumremovemodal').modal('show');

    };
    $scope.submitAlbumRemove = function() {
        $('#albumremovemodal').modal('hide');
        $http.delete('/api/albums/'+$scope.albumremove.id).then(function(data) {
            if (data.status == 200) {
                images.albums.splice(images.albums.indexOf($scope.albumremove), 1);
                // Unselect album if it was selected
                if($scope.albumremove == $scope.selectedAlbum) {
                    $scope.selectedAlbum = false;
                }
            }else {
                $scope.error = data.data;
            }
        });
    }
    $scope.accesstokenRemove = function(accesstoken) {
        $http.delete('/api/accesstokens/'+accesstoken.id).then(function(data) {
            if (data.status == 200) {
                images.accesstokens.splice(images.accesstokens.indexOf(accesstoken), 1);
            }else {
                $scope.error = data.data;
            }
        });
    }
    $scope.imageInfo = function(image) {
        $scope.imageinfo = image;
        $('#imageinfomodal').modal('show');
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


services.factory('images', ['$rootScope', '$http', function($rootScope, $http) {
    var images = {
        all: {},
        albums: [],
        images: [],
        photostreamimages: [],
        imagecount: {},
        accesstokens: [],
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
                $rootScope.$emit('imagesLoaded');
            });
        },
        getPhotoStreamFromBackend: function() {
            $http.get('/api/photostreamimages').then(function(data) {
                images.photostreamimages = data.data.photostreamimages;
                $rootScope.$emit('photostreamLoaded', '');
            });
        },
        getQueueCount: function() {
            $http.get('/api/queue').then(function(data) {
                var counter =  data.data['counter'];
                images.queueCount = counter;
            });
        },
        getAccestokensFromBackend: function(album) {
            $http.get('/api/accesstokens/'+album.id).then(function(data) {
                images.accesstokens = data.data.accesstokens;
            });
        },
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
