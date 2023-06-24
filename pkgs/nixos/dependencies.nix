{ config }:
rec {
    local-build = false;
    nixos-version = "23.05"; # Should match the channel in <nixpkgs>
    anix-version = "0.15.1";
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
