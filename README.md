photongx
========

A photo gallery with next to no chrome, written in lua deploying with nginx
See demo at <http://pex.hveem.no>


 * Full width thumbnails
 * Responsive design
 * Simplistic interface
 * Expirable URLs for albums
 * Super fast
 * Open source
 * Backend in lua
 * Redis as database
 * Runs on nginx (openresty)
 * Mozilla Persona for login
 * AngularJS admin panel
 * Is awesome!


Dev Installation
================


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



 
Roadmap for pexv2 codename pix
==============================

Store metadata in PostgreSQL
Scan EXIF in worker.py
EXIF in postgresql hstore  (exiftool -json 2013-06-30\ \#2/1372621341905.jpg)
Support pointing worker.py to a folder to let it generate thumbs and symlinks to real images
Proper API not just silly json structures
Proper admin pages
Multi user (atleast for some values of multi)

SQL schema

TODO: investigate nextval postgresql alphanumeric sequences for tags/ids
http://blog.endpoint.com/2009/08/text-sequences.html
OR

CREATE FUNCTION make_uid() RETURNS text AS $$
DECLARE
    new_uid text;
    done bool;
BEGIN
    done := false;
    WHILE NOT done LOOP
        new_uid := md5(''||now()::text||random()::text);
        done := NOT exists(SELECT 1 FROM my_table WHERE uid=new_uid);
    END LOOP;
    RETURN new_uid;
END;
$$ LANGUAGE PLPGSQL VOLATILE;

ALTER TABLE my_table ADD COLUMN uid text NOT NULL DEFAULT make_uid();


SELECT array_to_string(array((
                SELECT SUBSTRING('abcdefghjklmnpqrstuvwxyz23456789'
                    FROM mod((random()*32)::int, 32)+1 FOR 1)
                FROM generate_series(1,5))),'');


postgresql-9.1-pllua

create table users(
    id SERIAL PRIMARY KEY,
    email TEXT,
    name TEXT
);

create table album(
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL
        REFERENCES users(id),
    title TEXT,
    tag VARCHAR(6), 
    metadata hstore,
    views integer,
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now()

create table images(
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL
        REFERENCES users(id),
    album_id INTEGER NOT NULL
        REFERENCES album(id),
    tag VARCHAR(6), 
    title TEXT,
    file_name TEXT,
    thumb_name TEXT,
    huge_name TEXT,
    metadata hstore,
    views integer,
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now()
);

create table accesskeys (
    id SERIAL PRIMARY KEY,
    key text,
    user_id INTEGER NOT NULL
        REFERENCES users(id),
    album_id INTEGER NOT NULL
        REFERENCES album(id),
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now()
    expires_at
);

