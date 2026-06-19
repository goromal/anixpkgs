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
  anixpkgs = import anixpkgs-src { };
  unstable =
    import (builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz")
      { };
  service-ports = import ./service-ports.nix;
}
