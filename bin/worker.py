# -*- coding: utf-8 -*-

from redis import Redis
from PythonMagick import Image
import os
import sys

class Worker:
    def __init__(self):
        self.redis = Redis(unix_socket_path='/var/run/redis/redis.sock')

    def fetch_thumb_job(self):
        return self.redis.blpop('queue:thumb')[1]

    def thumbnail(infile, outfile, size):
        image = Image(filename)
        image.resize(size)
        image.write(outfile)

if __name__ == '__main__':
    BASE_DIR = os.path.dirname(__file__) + "/.."
    w = Worker()
    key = w.fetch_thumb_job()

    print key

    infile = BASE_DIR + "/static/img/" + key
    outfile = BASE_DIR + "/static/thumb/" + key

    w.thumbnail(infile, outfile, size="200x200")        

