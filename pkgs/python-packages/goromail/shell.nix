
{ pkgs ? import <nixpkgs> {} }:
let
  py = pkgs.python39.withPackages (p: with p; [
    requests
  ]);
in py.env
