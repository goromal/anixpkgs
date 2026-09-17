{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [ ../profiles/drone-obc-sim.nix ];
  drone.base.nixosState = "25.05";
  drone.base.machine = "sitl";
  networking.hostName = "drone-obc-sitl";

  # Placeholder root filesystem standing in for hardware configuration so
  # this closure evaluates standalone in CI (check_machines.sh, NixOS
  # Profile Diff). qemu-vm's mkVMOverride supersedes it in sitl-envs.
  fileSystems."/" = {
    device = "/dev/disk/by-label/NixOS";
    fsType = "ext4";
  };
}
