{ pkgs ? import <nixpkgs> {} }:
with pkgs;
mkShell {
    nativeBuildInputs = [
        evil-hangman
        spelling-corrector
        simple-image-editor
    ];
}
