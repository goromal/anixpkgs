{ pkgs ? import <nixpkgs> {} }:
with pkgs;
mkShell {
    nativeBuildInputs = [
        color-prints
        # evil-hangman
        # spelling-corrector
        # simple-image-editor
        abc
        doku
        epub
        gif
        html
        md
        midi
        mp3
        mp4
        pdf
        png
        svg
        zipper
    ];
}
