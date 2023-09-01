{ config, pkgs, lib, ... }:
with pkgs;
with lib; {
  imports = [ ../base.nix ];

  nix.nixPath = mkForce [ "nixpkgs=${cleanSource ../../..}" ];

  networking.hostName = "multirotorFcm";
  services.xserver.enable = true;
  services.xserver.displayManager = {
    lightdm.enable = true;
    defaultSession = lib.mkDefault "none+icewm";
    autoLogin = {
      enable = true;
      user = "andrew";
    };
  };
  services.xserver.windowManager.icewm.enable = true;

  environment.systemPackages = [ ];
}
