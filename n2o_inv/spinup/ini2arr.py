#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
This script reads config variables into the bash scripts
"""
import configparser
import sys

# read in config
config = configparser.ConfigParser()
config.read_file(sys.stdin)

# declare variables
for sec in config.sections():
    print("declare -A %s" % (sec))
    for key, val in config.items(sec):
        print('%s[%s]="%s"' % (sec, key, val))
