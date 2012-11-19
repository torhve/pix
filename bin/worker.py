#!/usr/bin/env python
#
# Worker module for generating thumbs and pulling exif info off images
# @author simeng
#
# -*- coding: utf-8 -*-

from redis import Redis
from PythonMagick import Image
import os
from os.path import sep
import sys
import json
from time import time
import signal
from optparse import OptionParser
#from subprocess import check_call as run
from subprocess import call as run

class Worker:
    def __init__(self, config):
        self.config = config
        self.work_list = None
        if 'redis' in config:
            # TODO support sockets and stuffs
            if 'unix_socket_path' in config["redis"]:
                self.redis = Redis(unix_socket_path = config["redis"]["unix_socket_path"])


    def fetch_thumb_job(self):
        if self.config['fetch_mode'] == 'queue':
            return self.redis.brpop('queue:thumb')[1]
        else:
            if self.work_list == None:
                self.work_list = []

                for album in self.redis.zrange('zalbums', 0, -1):
                    for key in self.redis.zrange(album, 0, -1):
                        self.work_list.append(key)

            return self.work_list.pop()

    def get_image_info(self, key):
        image = self.redis.hgetall(key)

        return image

    def save_image_info(self, imagekey, data):
        for key, value in data.items():
            self.redis.hset(imagekey, key, value)

    def rotate(self, infile):
        ''' Lossless autoration based on exif using jhead/jpegtran '''
        return run(['/usr/bin/jhead', '-autorot', infile])

    def thumbnail(self, infile, outfile, size, quality, no_upscale=False):
        #image = Image(infile)
        #image.resize(size)
        #image.write(outfile)

        quality = str(quality)
        if infile.endswith('.gif') or no_upscale:
            size = size+'>'
        resize = run(['/usr/bin/convert', '-interlace', "Plane", '-quality', quality, '-strip',  '-thumbnail', size, infile, outfile])
        image = Image(outfile)

        return { 'width': image.size().width(), \
                 'height': image.size().height() }

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
        except IndexError, e:
            break

        image = w.get_image_info(key)

        image['thumb_name'] = "t%d.%s" % ( photoconf['thumb_max'], image['file_name'] )
        image['huge_name'] = "t%d.%s" % ( photoconf['huge_max'], image['file_name'] )

        relbase = "img" + sep + image['atag'] + sep + image['itag'] + sep

        infile = BASE_DIR + sep + relbase + image['file_name']
        thumb_outfile = BASE_DIR + sep + relbase + image['thumb_name']
        huge_outfile = BASE_DIR + sep + relbase + image['huge_name']

        try:
            # First, rotate the original
            success = w.rotate(infile)

            if options.missing and os.path.exists(thumb_outfile):
                print 'Skipping existing thumbnail %s' %thumb_outfile
                continue
            else:
                print "Generating " + thumb_outfile,
                t = time()
                sys.stdout.flush()
                thumb = w.thumbnail(infile, thumb_outfile, thumb_max_size, quality)
                print "done (%d ms)" % ((time() - t) * 1000)

                update = { 'thumb_w': thumb['width'], \
                           'thumb_h': thumb['height'], \
                           'thumb_name': image['thumb_name'] }

                w.save_image_info(key, update)

            if options.missing and os.path.exists(huge_outfile):
                print 'Skipping existing hugenail %s' %huge_outfile
                continue
            else:
                print "Generating " + huge_outfile,
                t = time()
                sys.stdout.flush()
                huge = w.thumbnail(infile, huge_outfile, huge_max_size, quality, no_upscale=True)
                print "done (%d ms)" % ((time() - t) * 1000)

                update = { 'huge_w': huge['width'], \
                           'huge_h': huge['height'], \
                           'huge_name': image['huge_name'] }

                w.save_image_info(key, update)

        except Exception, e:
            print "ERROR", e
            print "Infile:", infile
            print "Outfile:", thumb_outfile
            print "Outfile:", huge_outfile
#3            raise

