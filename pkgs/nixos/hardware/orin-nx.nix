# ^^^^ THIS FILE IS TEMPORARY
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/0f7596f5-d29c-41da-8faa-4a6523d61528";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/5375-AF34";
    fsType = "vfat";
    options = [
      "fmask=0022"
      "dmask=0022"
    ];
  };

  # nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
