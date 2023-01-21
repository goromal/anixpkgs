#!/bin/bash

set -e pipefail

nb() {
nix-build . -A $1
}

echo "Building Python 3 packages (minus spleeter)..."

nb python3.pkgs.sunnyside
nb python3.pkgs.find_rotational_conventions
nb python3.pkgs.geometry
nb python3.pkgs.mavlog-utils
nb python3.pkgs.pyceres
nb python3.pkgs.pyceres_factors
nb python3.pkgs.pysorting
nb python3.pkgs.makepyshell
nb python3.pkgs.norbert
# nb python3.pkgs.spleeter
nb python3.pkgs.ichabod
nb python3.pkgs.pysignals
nb python3.pkgs.mesh-plotter
nb python310.pkgs.gmail-parser
nb python3.pkgs.trafficsim
nb python3.pkgs.imutils-cv4
nb python3.pkgs.vidstab-cv4
nb python3.pkgs.flask-hello-world
nb python3.pkgs.flask-url2mp4
nb python3.pkgs.flask-mp4server
nb python3.pkgs.flask-mp3server
nb python3.pkgs.flask-smfserver
nb python3.pkgs.rankserver
