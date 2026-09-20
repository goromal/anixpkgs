let
  nixos-version = (builtins.readFile ../../NIXOS_VERSION);
  anixpkgs-version = (builtins.readFile ../../ANIX_VERSION);
  anixpkgs-meta = (builtins.readFile ../../ANIX_META);
  nativeProcessTestsOverlay = _final: prev: {
    # QEMU user-mode emulation does not preserve posix_spawn's synchronous
    # ENOENT result. Keep SDL's process tests enabled and run this derivation
    # natively when an AArch64 machine also has emulated remote builders.
    sdl3 = prev.sdl3.overrideAttrs (
      _:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isAarch64 {
        preferLocalBuild = true;
      }
    );
  };
in
rec {
  local-build = false;
  inherit nixos-version; # Should match the channel in <nixpkgs>
  inherit anixpkgs-version;
  inherit anixpkgs-meta;
  anixpkgs-src =
    if local-build then
      # builtins.path explicitly registers the source tree in the Nix store, which is
      # required when running via `nix build .#...` (flake evaluation): Nix copies the
      # flake source into the store, so the relative path ../../. would resolve to a
      # /nix/store/HASH path. flake-compat's builtins.storePath then fails because the
      # sed-modified tree has a different hash. builtins.path forces a fresh store
      # registration of the current (modified) tree, making builtins.storePath succeed.
      builtins.path {
        path = ../../.;
        name = "anixpkgs-source";
        filter = p: t: baseNameOf p != ".git" && baseNameOf p != "result";
      }
    else
      (builtins.fetchTarball "https://github.com/goromal/anixpkgs/archive/refs/tags/v${anixpkgs-version}.tar.gz");
  anixpkgs = import anixpkgs-src {
    overlays = [ nativeProcessTestsOverlay ];
  };
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
