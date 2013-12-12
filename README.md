PEX - Photo Engine X
====================

A photo gallery with next to no chrome, written in lua deploying with nginx
See demo at <http://pix.hveem.no>


 * Full width thumbnails
 * Responsive design
 * Simplistic interface
 * Expirable shareable URLs for albums to share with friends
 * Super fast
 * Open source
 * Backend in MoonScript (Lapis Framework)
 * Runs on nginx (openresty)
 * Postgres as database
 * Redis as queue
 * Mozilla Persona for login
 * AngularJS admin panel
 * Is awesome!
 * Multi user
 * Display exif info
 
Features planned
================

 * Anonymous galleries
 * Linux utility that uploads images based on foldernames using API
 * Share from android ?
 * Sorty/query exif
 * Show disk space used
 * Tags
 * Export as ZIP archive
 * Organize photos into albums/tags
 * Date picker to find photos in a given time period
 * A "drop box" for fast/easy upload

Installation
================

*Warning*, this software project uses lots of uncommon requirements, so it can be a bit tricky to install. 
I have tried to documented all the steps required in the scripts/Dockerfile if you want a manual install if you do not wish to run Docker.

Watch Leafo's Lapis screencast to get familiar with Lapis <http://www.youtube.com/watch?v=Eo67iTY1Yf8>
It includes information that is relevant to this development process.

A Dockerfile is provided to get the project with all its requirements quickly up and running


Build the image

    $ docker build -t torhve/pix scripts/

This will build a complete docker image with all the requirements installed, database setup, and everything included.

You can then run it:

    $ docker run -i -t torhve/pix

To get the port number to connect your browser to use docker with -p argument, or inspect output from *docker ps*

If you want to configure or further hack you can use this command to get a bash prompt inside the docker image

    $ docker run -i -t torhve/pix bash


Configuration is in etc/config.json and config.moon

Deployment
==========

Use nginx with proxy_pass (or similar) to the lapis server port
 
