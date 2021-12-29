{ pkgs ? import <nixpkgs> {} }:
with pkgs;
mkShell {
    nativeBuildInputs = [
        color-prints
        evil-hangman
        spelling-corrector
        simple-image-editor
    ];
}
