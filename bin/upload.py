#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# CLI tool to upload images to a PEX installation
#
# author: @torhve

import pycurl
import sys
import os
from optparse import OptionParser
from random import choice
import hashlib


class Upper(object):

    def __init__(self, host):
        self.host = host


    def generate_tag(self):
        tag = ''.join(choice('abcdefghijklmnopqrstuvxyz1234567890') for _ in xrange(6))
        return tag

    def calcMD5(self, filename):
        return hashlib.md5(open(filename, 'r').read()).hexdigest()

    def upload(self, album, filename):
        fs = os.path.getsize(filename)
        c = pycurl.Curl()
        values = [
          "x-file-name: "+os.path.basename(filename),
          "X-Album: "+album,
          "X-Tag: "+self.generate_tag(),
          "X-Requested-With: XMLHttpRequest",
          "content-md5: "+self.calcMD5(filename)
        ]
        c.setopt(pycurl.HTTPHEADER, values)

        c.setopt(c.URL, self.host + "/photongx/upload/post/")
        c.setopt(c.POST, 1)
#        c.setopt(c.INFILESIZE, int(fs))
        c.setopt(pycurl.POSTFIELDSIZE, fs)
        c.setopt(pycurl.READFUNCTION, open(filename, 'r').read)

#        c.setopt(c.VERBOSE, 1)

        print "Uploading %s with size %.2f MiB to album %s:"%(filename, float(fs)/1024/1024, album),
        c.perform()
        c.close()

if __name__ == '__main__':
    parser = OptionParser()
    #parser.add_option('-r', '--recursive', dest="recurisve", action="store_true",
    #        help="give a folder, recurse through and upload all found images")
    parser.add_option('-a', '--album', dest="album",
            help="name of album to upload to")
    (options, args) = parser.parse_args(sys.argv)


    if len(args) < 2:
        parser.error("incorrect number of arguments")

    if not options.album:
        parser.error("required arg album not set")


    u = Upper(host='http://pex.hveem.no')

    u.upload(options.album, args[1])
