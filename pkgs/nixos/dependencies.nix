{ config }:
let
    anix-version = "0.3.0";
in {
    anixpkgs = import (builtins.fetchTarball "https://github.com/goromal/anixpkgs/archive/refs/tags/v${anix-version}.tar.gz") {
        config.allowUnfree = true;
    };
    unstable = import (builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz") {
        config = config.nixpkgs.config;
    };
}
