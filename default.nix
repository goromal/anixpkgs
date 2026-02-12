{
  overlays ? [ ],
  system ? builtins.currentSystem,
  ...
}@args:
let
  lock = builtins.fromJSON (builtins.readFile ./flake.lock);
  fetchLockedTarball =
    name:
    let
      node = lock.nodes.${name}.locked;
    in
    builtins.fetchTarball {
      url = "https://github.com/${node.owner}/${node.repo}/archive/${node.rev}.tar.gz";
      sha256 = node.narHash;
    };
  nixpkgs = fetchLockedTarball "nixpkgs";
  fetchLockedNode =
    name:
    let
      node = lock.nodes.${name}.locked;
    in
    if node.type == "github" then
      fetchLockedTarball name
    else
      builtins.fetchGit {
        url = node.url;
        rev = node.rev;
        submodules = node.submodules or false;
      };
  flakeInputs = builtins.mapAttrs (name: _: fetchLockedNode name) (
    builtins.removeAttrs lock.nodes [
      "root"
      "nixpkgs"
      "nixpkgs-unstable"
      "nixpkgs_2"
      "nixpkgs_3"
      "flake-compat"
      "flake-compat_2"
      "flake-utils"
    ]
  );
in
import nixpkgs {
  inherit system;
  overlays = [ (import ./overlay.nix) ] ++ overlays;
  config.flakeInputs = flakeInputs;
} // args
