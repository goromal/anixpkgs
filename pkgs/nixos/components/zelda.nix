{ pkgs, config, lib, ... }:
with pkgs;
with lib;
let cfg = config.mods.playzelda;
in {
  options.mods.playzelda = with types; {
    enable = mkEnableOption "enable playzelda";
    zeldaRom = mkOption {
      type = types.str;
      description = "Path to Zelda ROM";
      default = "/data/andrew/games/LegendOfZeldaCollectorsEdition.iso";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [
      (writeShellScriptBin "playzelda" ''
        ${pkgs.dolphinEmu}/bin/dolphin-emu -a LLE -e ${cfg.zeldaRom}
      '')
    ];
  };
}
