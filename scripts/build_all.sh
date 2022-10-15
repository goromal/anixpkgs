#!/bin/bash

set -e pipefail

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
nb manage-gmail
nb md2pdf
nb notabilify
nb fix-perms
nb make-title
nb pb
nb code2pdf
nb cpp-helper
nb mp4unite
nb git-cc

echo "Building C++ packages..."

nb manif-geom-cpp
nb ceres-factors
nb signals-cpp
nb secure-delete

echo "Building Java packages..."

nb evil-hangman
nb spelling-corrector
nb simple-image-editor

echo "Building Rust packages..."

nb xv-lidar-rs

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
nb python38.pkgs.gmail-parser
nb python38.pkgs.imutils-cv4
nb python38.pkgs.vidstab-cv4
nb python38.pkgs.flask-hello-world
nb python38.pkgs.flask-url2mp4
nb python38.pkgs.flask-mp4server
nb python38.pkgs.flask-mp3server
nb python38.pkgs.flask-smfserver

echo "Building ROS packages..."

nb rosPackages.noetic.std-msgs
nb rosPackages.noetic.geometry-msgs
nb rosPackages.noetic.message-generation
nb rosPackages.noetic.roscpp
nb rosPackages.noetic.rospy
nb rosPackages.noetic.nav-msgs
nb rosPackages.noetic.sensor-msgs
nb rosPackages.noetic.tf2
nb rosPackages.noetic.tf2-ros
nb rosPackages.noetic.visualization-msgs
# nb rosPackages.noetic.mav-comm
nb rosPackages.noetic.eigen-conversions
nb rosPackages.noetic.message-runtime
nb rosPackages.noetic.dynamic-reconfigure
nb rosPackages.noetic.ublox-msgs
nb rosPackages.noetic.eigen-stl-containers
nb rosPackages.noetic.tf
nb rosPackages.noetic.std-srvs
