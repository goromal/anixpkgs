{ config, pkgs, lib, ... }: {
  imports = [ ../base.nix ];

  machines.base = {
    machineType = "x86_linux";
    graphical = false;
    recreational = false;
    developer = false;
    isServer = true;
    isInstaller = false;
  };

  # TODO for now ATS needs to be founded on home-manager;
  # most of the content below is filler boilerplate for
  # ats-standalone-home.nix (for installer testing purposes ONLY)

  home-manager.users.andrew = {
    home.homeDirectory = pkgs.lib.mkForce "/home/andrew";
    imports = [ ../components/ats-standalone-home.nix ];
  };
}
