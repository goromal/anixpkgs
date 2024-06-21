 # TODO BROKEN; no running DHCP service. Build sd-aarch64 instead of the installer.
{ config, pkgs, ... }: {
  imports = [
    # <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix> <- Non-SD, for x86
    <nixpkgs/nixos/modules/installer/sd-card/sd-image-aarch64.nix>
    # Provide an initial copy of the NixOS channel so that the user
    # doesn't need to run "nix-channel --update" first.
    <nixpkgs/nixos/modules/installer/cd-dvd/channel.nix>
    ../profiles/ats.nix
  ];
  machines.base.nixosState = "24.05";
  machines.base.machineType = "pi4";
  machines.base.isInstaller = pkgs.lib.mkForce true;
}
# NIXPKGS_ALLOW_UNFREE=1 nixos-generate -f sd-aarch64-installer --system aarch64-linux -c /data/andrew/dev/anix/sources/anixpkgs/pkgs/nixos/installers/ats-pi.nix
