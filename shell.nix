{ pkgs ? import <nixpkgs> {} }:
with pkgs;
mkShell {
    nativeBuildInputs = [
        color-prints
        abc
        doku
        epub
        gif
        html
        md
        mp3
        mp4
        pdf
        png
        svg
        zipper
    ];
}
