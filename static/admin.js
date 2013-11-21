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
        images.getAllFromBackend();
        images.getImagesFromBackend();

        images.getQueueCount();
        // Update queue count on a timer
        var timer = setInterval(function() {
            images.getQueueCount();
            $scope.$apply();
        }, 6000);
    }

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

    $scope.submitNewAlbum = function() {
        $scope.uploading = true;
        $scope.selectedAlbum = false;
        var album = $scope.albumname;

        // Get tag from backend
        $http.get('/api/gentag/').then(function(data) {
            var tag = data.data.tag;
            // If we already have a tag defined for this album name it means
            // that we are uploading images to an existing album which means
            // we have to reuse the tag instead of using a generated one
            if(images.tags[album] != undefined) {
                tag = images.tags[album];
            }

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
    $scope.albumAdd = function(album) {
        $scope.uploading = true;
        $scope.selectedAlbum = false;
        $scope.albumname = album;
        $scope.submitNewAlbum();
        return false;
    }
    $scope.submitAlbumLink = function() {
        var formData = $('#form-ttl').serialize();
        var formUrl = "/admin/api/albumttl/create/";
        $.getJSON(formUrl, formData, function(data) { 
            console.log(data);
            $scope.linkAlbum = '';
            $('.modal').modal('hide');
        });
    };
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
        imagecount: {},
        accesskeys: {},
        accesskeysh: {},
        nrofimages: 0,
        thumbs: {},
        imagesarray: {},
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
              images.imagesarray = res.images;
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

services.factory("personaSvc", ["$http", "$q", function ($http, $q) {

  return {
        verify:function () {
            var deferred = $q.defer();
            navigator.id.get(function (assertion) {
                $http.post("/api/persona/verify", {assertion:assertion})
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


