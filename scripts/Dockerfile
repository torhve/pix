#
# Dockerfile for photongx
#
# VERSION   0.0.01


FROM ubuntu:12.04
MAINTAINER Tor Hveem <tor@hveem.no>
ENV REFRESHED_AT 2013-12-12

RUN echo "deb-src http://archive.ubuntu.com/ubuntu precise main" >> /etc/apt/sources.list
RUN sed 's/main$/main universe/' -i /etc/apt/sources.list
RUN apt-get update
RUN apt-get upgrade -y


RUN    apt-get -y install python-software-properties software-properties-common wget vim git inotify-tools pkg-config

# Redis
RUN    apt-get -y install redis-server

# PostgreSQL
RUN    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
RUN    echo "deb http://apt.postgresql.org/pub/repos/apt/ precise-pgdg main" > /etc/apt/sources.list.d/pgdg.list
RUN    apt-get update
RUN    apt-get -y install postgresql-9.3 postgresql-client-9.3 postgresql-contrib-9.3 libpq-dev

# Openresty (Nginx)
RUN    git clone https://github.com/evanmiller/mod_zip
RUN    apt-get -y build-dep nginx
RUN    wget http://openresty.org/download/ngx_openresty-1.4.3.6.tar.gz
RUN    tar xvfz ngx_openresty-1.4.3.6.tar.gz
RUN    cd ngx_openresty-1.4.3.6 ; ./configure --with-luajit  --with-http_addition_module --with-http_dav_module --with-http_geoip_module --with-http_gzip_static_module --with-http_image_filter_module --with-http_realip_module --with-http_stub_status_module --with-http_ssl_module --with-http_sub_module --with-http_xslt_module --with-ipv6 --with-http_postgres_module --with-pcre-jit --add-module=../mod_zip; make ; make install

# Tup
RUN    apt-add-repository 'deb http://ppa.launchpad.net/anatol/tup/ubuntu lucid main'
RUN    apt-get update
RUN    apt-get install -y tup
#RUN    git clone git://github.com/gittup/tup.git
#RUN    cd tup ; ./bootstrap.sh
#RUN    cp tup/tup /usr/bin 


# LESS compiler
RUN     add-apt-repository -y ppa:chris-lea/node.js
RUN     apt-get update
RUN     apt-get install -y nodejs 
RUN     npm install less -g

RUN    apt-get -y install libimage-exiftool-perl imagemagick jhead dcraw ufraw luarocks python-redis python-psycopg2



RUN    luarocks install --server=http://rocks.moonscript.org/manifests/leafo lapis
RUN    luarocks install --server=http://rocks.moonscript.org/manifests/leafo moonscript

RUN    git clone https://github.com/torhve/pix

RUN    cd pix; git submodule init; git submodule update

RUN    cd pix; tup init
# Compile MoonScript
RUN    cd pix; moonc *moon; moonc photongx/*moon; moonc photongx/views/*moon; moonc widgets/*moon
# Compile LESS => CSS
RUN    cd pix/static/; lessc screen.less screen.css
RUN    lessc pix/static/bootstrap/less/bootstrap.less pix/static/bootstrap/css/bootstrap.min.css


#RUN    service postgresql start
#RUN    service redis-server start

#RUN    lapis new --tup --git
#RUN    cd pix; tup init
#RUN    tup monitor -a

#Configure etc/config.json and config.moon

#Create the application tables
#Navigate browser to /db/create (requires a user to do, so you have to disable the user check for first run)
#
ADD postgresqlsetup.sh /pix/scripts/postgresqlsetup.sh
RUN /pix/scripts/postgresqlsetup.sh

ADD start.sh /start.sh

EXPOSE 8080
#CMD    bin/worker.py
#CMD    ["lapis", "server", "development"]
#CMD    ["/bin/su", "postgres", "-c", "/usr/lib/postgresql/9.3/bin/postgres -D /var/lib/postgresql/9.3/main -c config_file=/etc/postgresql/9.3/main/postgresql.conf"]
CMD /start.sh



