PEX - Photo Engine X
====================

A photo gallery with next to no chrome, written in lua deploying with nginx
See demo at <http://pex.hveem.no>


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
 
Features planned
================

 * Anonymous galleries
 * Linux utility that uploads images based on foldernames using API
 * Share from android ?
 * Display exif info
 * Sorty/query exif
 * Show disk space used


Dev Installation
================


Preqreqs
    sudo apt-get install libimage-exiftool-perl imagemagick redis-server jhead

PostgreSQL with hstore

    sudo apt-get install postgresql-server postgresql-contrib

Tup for developing
    sudo apt-add-repository 'deb http://ppa.launchpad.net/anatol/tup/ubuntu precise main'
    sudo apt-get update
    sudo apt-get install tup
Lapis 
    luarocks install --server=http://rocks.moonscript.org/manifests/leafo lapis
    
First time:
    lapis new --tup --git

    tup init
    tup monitor -a
    lapis server development 

Create postgresql database:
    sudo -u postgres psql template1 < scripts/create-postgres-database.sql

Create the application tables
    Navigate browser to /db/create (requires a user to do, so you have to disable the user check for first run)


Deployment
==========

Start the image postprocessing utility: bin/worker.py 
 
