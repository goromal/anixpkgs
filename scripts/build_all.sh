#!/bin/bash

nb() {
nix-build . -A $1
}

echo "Building Bash packages..."

nb abc
nb doku
nb epub
nb gif
nb html
nb md
nb mp3
nb mp4
nb pdf
nb png
nb svg
nb zipper
nb color-prints 

echo "Building C++ packages..."

nb manif-geom-cpp
nb ceres-factors
nb signals-cpp

echo "Building Java packages..."

nb evil-hangman
nb spelling-corrector
nb simple-image-editor

echo "Building Python 3.8 packages (minus spleeter)..."

nb python38.pkgs.sunnyside
nb python38.pkgs.geometry
nb python38.pkgs.pyceres
nb python38.pkgs.pyceres_factors
nb python38.pkgs.norbert
# nb python38.pkgs.spleeter
nb python38.pkgs.ichabod
nb python38.pkgs.pysignals
nb python38.pkgs.mesh-plotter
nb python38.pkgs.imutils-cv4
nb python38.pkgs.vidstab-cv4
nb python38.pkgs.flask-hello-world
nb python38.pkgs.flask-url2mp4
nb python38.pkgs.flask-mp4server
nb python38.pkgs.flask-mp3server
nb python38.pkgs.flask-smfserver
