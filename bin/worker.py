#!/usr/bin/env python
#
# Worker module for generating thumbs and pulling exif info off images
# @author simeng
#
# -*- coding: utf-8 -*-

from redis import Redis
import os
from os.path import sep
import sys
import json
from time import time
import signal
from optparse import OptionParser
import psycopg2
import psycopg2.extras 
#from subprocess import check_call as run
from subprocess import check_output as run
from time import sleep

class Database:
    def __init__(self, config):
        self.pg = psycopg2.connect(config['postgresql']['connstring'])
        psycopg2.extras.register_hstore(self.pg) # This is what forces psycopg2 to interface Dicts with hstores.
        self.cursor = self.pg.cursor(cursor_factory=psycopg2.extras.DictCursor)

    def get_image(self, token):
        self.cursor.execute('SELECT * from images where token = %s', (token,))
        image = self.cursor.fetchone()

        return image

    def save_image_info(self, token, update):
        for key, val in update.items():
            command = 'UPDATE images set '+key+' = %s WHERE token = %s'
            self.cursor.execute(command, (val, token))
        self.pg.commit()

    def __del__(self):
        self.pg.close()

class Worker:
    def __init__(self, config):
        self.config = config
        self.work_list = None
        if 'redis' in config:
            if 'unix_socket_path' in config["redis"]:
                self.redis = Redis(unix_socket_path = config["redis"]["unix_socket_path"])

        self.db = Database(config)


    def fetch_thumb_job(self):
        if self.config['fetch_mode'] == 'queue':
            return self.redis.brpop('pix:upload:queue')[1]
        else:
            if self.work_list == None:
                self.work_list = []

                for album in self.redis.zrange('zalbums', 0, -1):
                    for key in self.redis.zrange(album, 0, -1):
                        self.work_list.append(key)

            return self.work_list.pop()

    def get_image_info(self, token):
        image = self.db.get_image(token)
        return image

    def save_image_info(self, imagekey, data):
        self.db.save_image_info(imagekey, data)

    def rotate(self, infile):
        ''' Lossless autoration based on exif using jhead/jpegtran '''
        try:
            return run(['/usr/bin/jhead', '-autorot', infile])
        except Exception, e:
            print e

    def get_exif(self, infile):
        ''' Return exif as json. Convert every value to str since we store it as hstore in postgresql which does not support numeric values '''

        exif = json.loads(run(['/usr/bin/exiftool', '-json', infile]))[0]
        res = {}
        for key, val in exif.items():
            try:
               res[key] = str(val)
            except Exception, e:
                print 'Error with exif parsing:',e
        return res

    def thumbnail(self, infile, outfile, size, quality, no_upscale=False):
        quality = str(quality)
        if infile.endswith('.gif') or no_upscale:
            size = size+'>'
        resize = run(['/usr/bin/convert', '-filter', 'catrom', '-interlace', "Plane", '-quality', quality, '-strip',  '-thumbnail', size, infile, outfile])

if __name__ == '__main__':
    parser = OptionParser()
    parser.add_option('-a', '--all', dest="all", action="store_true", 
            help="worker will ignore queue, process all images in database and exit")
    parser.add_option('-m', '--missing', dest="missing", action="store_true", 
            help="only generate for missing thumbnails")
    (options, args) = parser.parse_args(sys.argv)

    BASE_DIR = os.path.dirname(__file__) + "/.."
    with open(BASE_DIR + sep + "etc" + sep + "config.json") as f:
        config = json.loads(f.read())

    signal.signal(signal.SIGINT, lambda num, frame: sys.exit(0))

    if options.all:
        config['fetch_mode'] = 'all'
    else:
        config['fetch_mode'] = 'queue'

    w = Worker(config)
    photoconf = config['photos']
    thumb_max_size = "%dx%d" % ( photoconf['thumb_max'], photoconf['thumb_max'] )
    huge_max_size = "%dx%d" % ( photoconf['huge_max'], photoconf['huge_max'] )
    quality = '%d' % (photoconf['quality'] )

    while True:
        try:
            key = w.fetch_thumb_job()
            #print 'Got key bun syncing', run('sync')
        except IndexError, e:
            break

        image = w.get_image_info(key)
        if not image:
          # Happens if user deletes image before queue gets to process it
          continue

        image['thumb_name'] = "t%d.%s" % ( photoconf['thumb_max'], image['file_name'] )
        image['huge_name'] = "t%d.%s" % ( photoconf['huge_max'], image['file_name'] )

        relbase = sep.join([BASE_DIR, config['path']['image'], str(image['user_id']), str(image['album_id']), str(image['id'])]) + sep

        infile = relbase + image['file_name']
        thumb_outfile = relbase + image['thumb_name']
        huge_outfile = relbase + image['huge_name']

        try:
            # First, rotate the original
            success = w.rotate(infile)

            # Get Exif
            exif = w.get_exif(infile)

            update = {
                'metadata': exif
            }

            if options.missing and os.path.exists(thumb_outfile):
                print 'Skipping existing thumbnail %s' %thumb_outfile
                continue
            else:
                print "Generating " + thumb_outfile,
                t = time()
                sys.stdout.flush()
                thumb = w.thumbnail(infile, thumb_outfile, thumb_max_size, quality)
                print "done (%d ms)" % ((time() - t) * 1000)

                update['thumb_name'] = image['thumb_name'],

            if options.missing and os.path.exists(huge_outfile):
                print 'Skipping existing hugenail %s' %huge_outfile
                continue
            else:
                print "Generating " + huge_outfile,
                t = time()
                sys.stdout.flush()
                huge = w.thumbnail(infile, huge_outfile, huge_max_size, quality, no_upscale=True)
                print "done (%d ms)" % ((time() - t) * 1000)

                update['huge_name'] = image['huge_name']

            w.save_image_info(key, update)

        except Exception, e:
            print "ERROR", e
            print "Inffile:", infile
            print "Thumb Outfile:", thumb_outfile
            print "Huge Outfile:", huge_outfile
            raise

