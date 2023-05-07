#!/usr/bin/env python

import argparse
import os
import re

ROOTDIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def get_sources_info():
    urls = []
    with open(os.path.join(ROOTDIR, "sources.nix"), "r") as sources_file:
        url_pattern = re.compile(r"builtins.fetchGit\s*\{\s*\n\s*url\s*=\s*\"(.+)\";", re.MULTILINE)
        print(re.findall(url_pattern, sources_file.read()))
    # TODO

if __name__ == "__main__":
    get_sources_info()