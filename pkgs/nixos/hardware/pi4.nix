# https://nix.dev/tutorials/installing-nixos-on-a-raspberry-pi
{
  config,
  pkgs,
  lib,
  ...
}:
with pkgs;
with lib;
let
  hwArch = fetchTarball "https://github.com/NixOS/nixos-hardware/archive/acb4f0e9bfa8ca2d6fca5e692307b5c994e7dbda.tar.gz";
in
{
  imports = [ "${hwArch}/raspberry-pi/4" ];

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" ];
    };
  };

  # Enable GPU acceleration
  hardware.raspberry-pi."4".fkms-3d.enable = true;

  # Use 1GB of additional swap memory in order to not run out of memory
  # when installing lots of things while running other things at the same time.
  swapDevices = [
    {
      device = "/swapfile";
      size = 1024;
    }
  ];
}
