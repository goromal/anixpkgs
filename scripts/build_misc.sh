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
nb pkgshell

echo "Building Java packages..."

nb evil-hangman
nb spelling-corrector
nb simple-image-editor

echo "Building Rust packages..."

nb xv-lidar-rs
