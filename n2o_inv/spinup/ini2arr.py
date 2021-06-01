#!/usr/bin/env python

import configparser
import sys

config = configparser.ConfigParser()
config.read_file(sys.stdin)

for sec in config.sections():
    print("declare -A %s" % (sec))
    for key, val in config.items(sec):
        print('%s[%s]="%s"' % (sec, key, val))
