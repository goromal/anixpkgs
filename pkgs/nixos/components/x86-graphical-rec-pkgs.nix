{ pkgs, config, lib, ... }:
with pkgs;
with import ../dependencies.nix { inherit config; };
let cfg = config.mods.x86-graphical-rec;
in {
  options.mods.x86-graphical-rec = with types; {
    zeldaRom = mkOption {
      type = types.str;
      description = "Path to Zelda ROM";
      default = "/data/andrew/games/LegendOfZeldaCollectorsEdition.iso";
    };
  };

  config = {
    home.packages = [
      anixpkgs.trafficsim
      anixpkgs.la-quiz
      (writeShellScriptBin "playzelda" ''
        ${pkgs.dolphinEmu}/bin/dolphin-emu -a LLE -e ${cfg.zeldaRom}
      '')
    ];
  };
}
