# -*- coding: utf-8 -*-

from redis import Redis
from PythonMagick import Image
import os
from os.path import sep
import sys
import json

class Worker:
    def __init__(self, config):
        if 'redis' in config:
            # TODO support sockets and stuffs
            if 'unix_socket_path' in config["redis"]:
                self.redis = Redis(unix_socket_path = config["redis"]["unix_socket_path"])

    def fetch_thumb_job(self):
        return self.redis.blpop('queue:thumb')[1]

    def thumbnail(self, infile, outfile, size):
        image = Image(infile)
        image.resize(size)
        image.write(outfile)

if __name__ == '__main__':
    BASE_DIR = os.path.dirname(__file__) + "/.."
    with open(BASE_DIR + sep + "etc" + sep + "config.json") as f:
        config = json.loads(f.read())

    w = Worker(config)
    key = w.fetch_thumb_job()

    print key

    infile = BASE_DIR + "/static/img/" + key
    outfile = BASE_DIR + "/static/thumb/" + key

    w.thumbnail(infile, outfile, size="200x200")        

