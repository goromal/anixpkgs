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

  # S3 firmware dev: build arducopter (the goromal/ardupilot fork, with the
  # INDI custom-controller backend) and indi-harness from local working
  # checkouts instead of the flake.lock pins. Flip to true locally to validate
  # the s3-layerA sitl-env before the pins are bumped; keep false on committed/
  # CI builds (which use the pinned inputs). Requires local-build = true.
  drone-local-fork = false;
  drone-fork-paths = {
    ardupilot = "/data/andrew/dev/drone/sources/ardupilot";
    indi-harness = "/data/andrew/dev/drone/sources/indi-harness";
  };
  # Overlay (composed after overlay.nix, so it sees the flake.lock-based
  # flakeInputs as prev) that repoints ardupilot + indi-harness at the local
  # working checkouts. default.nix threads `overlays` through, and arducopter /
  # the indi-harness python package both read final.flakeInputs.
  droneForkOverlay = final: prev: {
    flakeInputs = prev.flakeInputs // {
      ardupilot = builtins.fetchGit {
        url = "file://${drone-fork-paths.ardupilot}";
        ref = "HEAD";
        submodules = true;
      };
      indi-harness = builtins.fetchGit {
        url = "file://${drone-fork-paths.indi-harness}";
        ref = "HEAD";
      };
    };
  };
  anixpkgs = import anixpkgs-src (
    if drone-local-fork then { overlays = [ droneForkOverlay ]; } else { }
  );
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
