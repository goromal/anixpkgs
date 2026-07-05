{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [ ../drone-base.nix ];

  drone.base = {
    # TODO machine-agnostic drone OBC sim configs as they arise
  };
}
