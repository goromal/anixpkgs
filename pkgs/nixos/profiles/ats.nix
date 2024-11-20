{ config, pkgs, lib, ... }: {
  imports = [ ../pc-base.nix ];

  machines.base = {
    machineType = "x86_linux";
    graphical = false;
    recreational = false;
    developer = false;
    loadATSServices = true;
    serveNotesWiki = true;
    notesWikiPort = 8080;
    isInstaller = false;
  };

  users.users.andrew.hashedPassword = lib.mkForce
    "$6$Kof8OUytwcMojJXx$vc82QBfFMxCJ96NuEYsrIJ0gJORjgpkeeyO9PzCBgSGqbQePK73sa13oK1FGY1CGd09qbAlsdiXWmO6m9c3K.0";
}
