# -*- coding: utf-8 -*-

from redis import Redis
from PythonMagick import Image
import os
from os.path import sep
import sys
import json
from time import time
import signal

class Worker:
    def __init__(self, config):
        if 'redis' in config:
            # TODO support sockets and stuffs
            if 'unix_socket_path' in config["redis"]:
                self.redis = Redis(unix_socket_path = config["redis"]["unix_socket_path"])

    def fetch_thumb_job(self):
        return self.redis.blpop('queue:thumb')[1]

    def get_image_info(self, key):
        image = self.redis.hgetall(key)

        image['thumb_name'] = "t640." + image['file_name']

        base = "img" + sep + image['atag'] + sep + image['itag'] + sep
        image['relpath'] = base + image['file_name']
        image['relpath_thumb_640'] = base + image['thumb_name']

        return image

    def save_image_info(self, imagekey, data):
        for key, value in data.items():
            self.redis.hset(imagekey, key, value)

    def thumbnail(self, infile, outfile, size):
        image = Image(infile)
        image.resize(size)
        image.write(outfile)

        return { 'width': image.size().width(), \
                 'height': image.size().height() }

if __name__ == '__main__':
    BASE_DIR = os.path.dirname(__file__) + "/.."
    with open(BASE_DIR + sep + "etc" + sep + "config.json") as f:
        config = json.loads(f.read())

    signal.signal(signal.SIGINT, lambda num, frame: sys.exit(0))

    w = Worker(config)

    while True:
        key = w.fetch_thumb_job()
        image = w.get_image_info(key)

        infile = BASE_DIR + sep + image['relpath']
        outfile = BASE_DIR + sep + image['relpath_thumb_640']

        print "Generating " + outfile,
        t = time()
        sys.stdout.flush()
        thumb = w.thumbnail(infile, outfile, size="640x640")        
        print "done (%d ms)" % ((time() - t) * 1000)

        update = { 'thumb_w': thumb['width'], \
                   'thumb_h': thumb['height'], \
                   'thumb_name': image['thumb_name'] }

        w.save_image_info(key, update)

