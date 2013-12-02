/* FileAPI from filebin.net (C) Espen Braastad */
/* Modifications by Tor Hveem */
var FileAPI = (function (c, t, d, f) {
  
      var fileCount = c,
          fileList = t,
          dropZone = d,
          fileField = f,
          counter_queue = 0,
          album,
          counter_uploading = 0,
          counter_completed = 0,
          fileQueue = new Array(),
          preview = null;
  
      this.init = function () {
          fileField.onchange = this.addFiles;
          dropZone.addEventListener("dragenter",  this.stopProp, false);
          dropZone.addEventListener("dragleave",  this.dragExit, false);
          dropZone.addEventListener("dragover",  this.dragOver, false);
          dropZone.addEventListener("drop",  this.showDroppedFiles, false);
      }

      this.setAlbum = function(a) {
          album = a;
      }
  
      this.addFiles = function () {
          addFileListItems(this.files);
      }
  
      function updateFileCount() {
          var text = "Status: " + counter_completed + " of " + counter_queue + " file";
          if (counter_queue != 1){
              text = text + "s";
          }
          text = text + " uploaded";

          if (counter_completed == counter_queue) {
              fileCount.textContent = text + ", all done!";
        } else {
              fileCount.textContent = text + ", please wait ...";
        }
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
          if (ev != undefined) 
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
              var div = document.createElement("div");
              div.className = "loader";
              var divText = document.createTextNode("Pending...");
              div.appendChild(divText);
              item.li.appendChild(div);
              if (item.file.size < 32212254720) {
                  div.style["color"] = "#3a87ad";
                  uploadFile(item.file, item.li);
              } else {
                  div.textContent = "File to large (>30GB)";
                  div.style["color"] = "red";
              }
          }
      }
  
      var addFileListItems = function (files) {
          counter_queue += files.length;
          updateFileCount();

          for (var i = 0; i < files.length; i++) {
              var fr = new FileReader();
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
              //if (file.type.search(/image\/.*/) != -1) {
              //    var thumb = new Image();
              //    thumb.src = ev.target.result;
              //    thumb.addEventListener("mouseover", showImagePreview, false);
              //    thumb.addEventListener("mouseout", removePreview, false);
              //    li.appendChild(thumb);
              //}
              var mime = file.type;
              if (mime.length == 0){
                  mime = "unknown";
              }
              var pText = document.createTextNode(
                  file.name + ", " +
                  mime + ", size: " +
                  Math.round(file.size / 1024 / 1024) + " MB"
              );
              li.appendChild(pText);
              var divContainer = document.createElement("div");
              divContainer.className = "progress";
              var divLoader = document.createElement("div");
              divLoader.className = "progress-bar";
              li.appendChild(divContainer);
              divContainer.appendChild(divLoader);
              fileList.appendChild(li);

              counter_uploading += 1;
              updateFileCount();

              fileQueue.push({
                  file : file,
                  li : li
              });
          }
      }
  
      //var showImagePreview = function (ev) {
      //    var div = document.createElement("div");
      //    div.style["top"] = (ev.pageY + 10) + "px";
      //    div.style["left"] = (ev.pageX + 10) + "px";
      //    div.style["opacity"] = 0;
      //    div.className = "imagePreview";
      //    var img = new Image();
      //    img.src = ev.target.src;
      //    div.appendChild(img);
      //    document.body.appendChild(div);
      //    document.body.addEventListener("mousemove", movePreview, false);
      //    preview = div;
      //    fadePreviewIn();
      //}
  
      //var movePreview = function (ev) {
      //    if (preview) {
      //        preview.style["top"] = (ev.pageY + 10) + "px";
      //        preview.style["left"] = (ev.pageX + 10) + "px";
      //    }
      //}
  
      //var removePreview = function (ev) {
      //    document.body.removeEventListener("mousemove", movePreview, false);
      //    document.body.removeChild(preview);
      //}
  
      //var fadePreviewIn = function () {
      //    if (preview) {
      //        var opacity = preview.style["opacity"];
      //        for (var i = 10; i < 250; i = i+10) {
      //            (function () {
      //                var level = i;
      //                setTimeout(function () {
      //                    preview.style["opacity"] = opacity + level / 250;
      //                }, level);
      //            })();
      //        }
      //    }
      //}

      function roundNumber(num, dec) {
          var result = Math.round(num*Math.pow(10,dec))/Math.pow(10,dec);
          return result;
      }
  
      var uploadFile = function (file, li) {
          if (li && file) {
              var xhr = new XMLHttpRequest(),
                  upload = xhr.upload,
                  fd = FormData();

              upload.addEventListener("progress", function (ev) {
                  if (ev.lengthComputable) {
                      var loader = li.getElementsByTagName("div")[1];
                      loader.style["width"] = (ev.loaded / ev.total) * 100 + "%";
                      var ps = li.getElementsByTagName("div");
                      for (var i = 0; i < ps.length; i++) {
                          if (ps[i].className == "loader") {
                              var percent = (ev.loaded / ev.total) * 100;
                              ps[i].textContent = "Uploading... " + percent.toFixed(2) + "%";
                              ps[i].style["color"] = "#000000";
                              break;
                          }
                      }
                  }
              }, false);
              upload.addEventListener("load", function (ev) {
                  var ps = li.getElementsByTagName("div");
                  var divContainer = li.getElementsByTagName("div")[0];
                  var divBar = li.getElementsByTagName("div")[1];
                  divBar.style["width"] = "100%";
                  for (var i = 0; i < ps.length; i++) {
                      if (ps[i].className == "loader") {
                          counter_uploading -= 1;
                          counter_completed += 1;
                          updateFileCount();

                          ps[i].textContent = xhr.responseText;
                          //ps[i].style["color"] = "white";
                          break;
                      }
                  }
              }, false);
              upload.addEventListener("error", function (ev) {console.log(ev);}, false);
              upload.addEventListener("abort", function (ev) {console.log(ev);}, false);
              fd.append("upload", file);
              xhr.open(
                  "POST",
                  "/api/images"
              );
              xhr.setRequestHeader("X-Requested-With", "XMLHttpRequest");
              fd.append("filename", file.name);
              fd.append("size", file.size);
              fd.append("title", album.title);
              fd.append("token", album.token);
              // TODO use filereader to read file and check md5
              fd.append("checksum", calcMD5(file));
              // Check upload respone and error message
              xhr.onload = function() {
                  var ps = li.getElementsByTagName("div");
                  var divContainer = li.getElementsByTagName("div")[0];
                  var divBar = li.getElementsByTagName("div")[1];
                  if(xhr.status == 200) {
                      divContainer.className = "progress";
                      divBar.className = "progress-bar progress-bar-success";
                  }else if(xhr.status == 403) {
                      divBar.className = "progress-bar progress-bar-danger";
                  }
                  for (var i = 0; i < ps.length; i++) {
                      if (ps[i].className == "loader") {
                          ps[i].textContent = xhr.responseText;
                          break;
                      }
                  }
              }
              xhr.send(fd);
          }
      }
  }
);
