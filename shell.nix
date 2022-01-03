{ pkgs ? import <anixpkgs> }:
with pkgs;
mkShell {
    nativeBuildInputs = [
        evil-hangman
    ];
}
