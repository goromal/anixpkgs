let
  nixos-version = (builtins.readFile ../../NIXOS_VERSION);
  anixpkgs-version = (builtins.readFile ../../ANIX_VERSION);
  anixpkgs-meta = (builtins.readFile ../../ANIX_META);
in
rec {
  local-build = false;
  inherit nixos-version; # Should match the channel in <nixpkgs>
  inherit anixpkgs-version;
  inherit anixpkgs-meta;
  anixpkgs-src =
    if local-build then
      ../../default.nix
    else
      (builtins.fetchTarball "https://github.com/goromal/anixpkgs/archive/refs/tags/v${anixpkgs-version}.tar.gz");
  anixpkgs = import anixpkgs-src { };
  unstable =
    import (builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz")
      { };
  # ROS2 package set from nix-ros-overlay, built on its own pinned nixpkgs
  # (required for compatibility and for ros.cachix.org binary cache hits).
  ros-pkgs =
    let
      lock = builtins.fromJSON (builtins.readFile ../../flake.lock);
    in
    import (fetchTarball {
      url = "https://github.com/lopsided98/nix-ros-overlay/archive/${lock.nodes.nix-ros-overlay.locked.rev}.tar.gz";
      sha256 = lock.nodes.nix-ros-overlay.locked.narHash;
    }) { };
  service-ports = import ./service-ports.nix;
}
