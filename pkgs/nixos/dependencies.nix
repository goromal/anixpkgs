{ config }:
rec {
    local-build = false;
    anix-version = "0.10.2";
    anixpkgs = import (if local-build then
        ../../default.nix else
        (builtins.fetchTarball "https://github.com/goromal/anixpkgs/archive/refs/tags/v${anix-version}.tar.gz"))
    {
        config.allowUnfree = true;
    };
    unstable = import (builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz")
    {
        config = config.nixpkgs.config;
    };
}
