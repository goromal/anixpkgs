{ pkgs ? import <anixpkgs> }:
with pkgs;
mkShell {
    nativeBuildInputs = [
        evil-hangman
	    spelling-corrector
        simple-image-editor
    ];
}
