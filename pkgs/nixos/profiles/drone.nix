{ config, pkgs, lib, ... }: {
  imports = [ ../drone-base.nix ];

  drone.base = {
    # TODO machine-agnostic configs as they arise
  };
}
