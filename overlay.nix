final: prev:
let
  # nix-ros-overlay is deliberately NOT composed in here. Its overlay patches
  # base packages (libfyaml among them), and libfyaml reaches chromium through
  # appstream -> libadwaita -> zenity -> sdl3 -> sdl2-compat -> ffmpeg, so every
  # machine applying this overlay system-wide loses the binary cache for the
  # whole GNOME/ffmpeg/chromium chain and compiles chromium from source. ROS
  # consumers take their packages from `ros-pkgs` in pkgs/nixos/dependencies.nix,
  # which imports nix-ros-overlay as its own package set on its own pinned
  # nixpkgs, so the ROS side is unaffected by this.
  flakeInputs =
    let
      flake-compat = import (
        let
          lock = builtins.fromJSON (builtins.readFile ./flake.lock);
        in
        fetchTarball {
          url = "https://github.com/edolstra/flake-compat/archive/${lock.nodes.flake-compat.locked.rev}.tar.gz";
          sha256 = lock.nodes.flake-compat.locked.narHash;
        }
      );
    in
    final.config.flakeInputs or (flake-compat {
      src = final.lib.cleanSource ./.;
    }).defaultNix.inputs;
in
(import ./pkgs final prev)
// {
  inherit flakeInputs;
}
