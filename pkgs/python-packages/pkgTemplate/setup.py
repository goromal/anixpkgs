#!/usr/bin/env python

import os
from setuptools import setup, find_packages

about = {}  # type: ignore
here = os.path.abspath(os.path.dirname(__file__))
with open(os.path.join(here, '__version__.py')) as f:
    exec(f.read(), about)

# package configuration - for reference see:
# https://setuptools.readthedocs.io/en/latest/setuptools.html#id9
setup(
    name=about['__title__'],
    description=about['__description__'],
    version=about['__version__'],
    author=about['__author__'],
    author_email=about['__author_email__'],
    packages=find_packages(),
    include_package_data=True,
    entry_points={},
)
