{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [ ../drone-base.nix ];

  drone.base = {
    runAPSITL = true;
  };
}
