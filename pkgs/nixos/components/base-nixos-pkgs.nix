{ pkgs, config, lib, ...}:
with pkgs;
with import ../dependencies.nix { inherit config; }; {
  imports = [
    ./base-pkgs.nix
  ];

  home.packages = [
    docker
    anixpkgs.anix-version
    anixpkgs.anix-upgrade
  ];

  home.file = {
    ".anix-version".text =
      if local-build then "Local Build" else "v${anix-version}";
  };
}
