#!/bin/bash

set -e pipefail

nb() {
nix-build . -A $1
}

echo "Building Python 3 packages (minus spleeter)..."

nb python39.pkgs.aapis-py
nb python39.pkgs.sunnyside
nb python39.pkgs.find_rotational_conventions
nb python39.pkgs.geometry
nb python39.pkgs.mavlog-utils
nb python39.pkgs.pyceres
nb python39.pkgs.pyceres_factors
nb python39.pkgs.pysorting
nb python39.pkgs.makepyshell
nb python39.pkgs.norbert
# nb python39.pkgs.spleeter
nb python39.pkgs.ichabod
nb python39.pkgs.pysignals
nb python39.pkgs.mesh-plotter
nb python310.pkgs.gmail-parser
nb python39.pkgs.trafficsim
nb python39.pkgs.imutils-cv4
nb python39.pkgs.vidstab-cv4
nb python39.pkgs.flask-hello-world
nb python39.pkgs.flask-url2mp4
nb python39.pkgs.flask-mp4server
nb python39.pkgs.flask-mp3server
nb python39.pkgs.flask-smfserver
nb python39.pkgs.flask-oatbox
nb python39.pkgs.rankserver
nb python310.pkgs.python-dokuwiki
nb python310.pkgs.wiki-tools
nb python310.pkgs.book-notes-sync
