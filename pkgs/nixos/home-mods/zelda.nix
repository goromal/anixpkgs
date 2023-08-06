{ pkgs, config, lib, ... }:
with pkgs; with lib;
let
  cfg = config.mods.playzelda;
in
{
  options.mods.playzelda = with types; {
    enable = mkEnableOption "enable playzelda";
    packages = mkOption {
      type = types.package;
      description = "The nixpkgs to use";
    };
    zeldaRom = mkOption {
      type = types.str;
      description = "Path to Zelda ROM";
      default = "/data/andrew/Dropbox/Games/LegendOfZeldaCollectorsEdition.iso";
    };
  };

  config = mkIf cfg.enable {
    # services.udev.packages = [ cfg.packages.dolphinEmu ];
    home.packages = [
      (writeShellScriptBin "playzelda" ''
        ${builtins.getAttr "dolphinEmu" (import cfg.packages {})}/bin/dolphin-emu -a LLE -e ${cfg.zeldaRom}
      '')
    ];
  };
}
