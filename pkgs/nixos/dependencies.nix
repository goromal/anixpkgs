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
  # Flake inputs (e.g. llm-agents) for home-manager components. Those modules run
  # with their own pkgs instance that lacks the anixpkgs overlay, so `pkgs.flakeInputs`
  # is unavailable there; derive the inputs via flake-compat on the repo root instead
  # (mirrors overlay.nix). Consume as e.g. `flakeInputs.llm-agents.packages.${pkgs.system}.codex`.
  flakeInputs =
    let
      lock = builtins.fromJSON (builtins.readFile ../../flake.lock);
      flake-compat = import (
        builtins.fetchTarball {
          url = "https://github.com/edolstra/flake-compat/archive/${lock.nodes.flake-compat.locked.rev}.tar.gz";
          sha256 = lock.nodes.flake-compat.locked.narHash;
        }
      );
    in
    (flake-compat { src = ../../.; }).defaultNix.inputs;
}
