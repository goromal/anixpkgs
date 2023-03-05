{ config }:
rec {
    anix-version = "0.8.0";
    # anixpkgs = import <anixpkgs>
    anixpkgs = import (builtins.fetchTarball "https://github.com/goromal/anixpkgs/archive/refs/tags/v${anix-version}.tar.gz")
    {
        config.allowUnfree = true;
    };
    unstable = import (builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz")
    {
        config = config.nixpkgs.config;
    };
}
