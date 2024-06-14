{ config, pkgs, ... }: {
  imports = [
    <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix>
    # Provide an initial copy of the NixOS channel so that the user
    # doesn't need to run "nix-channel --update" first.
    <nixpkgs/nixos/modules/installer/cd-dvd/channel.nix>
    ../profiles/ats.nix
  ];
  machines.base.nixosState = "24.05";
  machines.base.isInstaller = pkgs.lib.mkForce true;
}
