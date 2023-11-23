{ pkgs, config, lib, ... }:
with pkgs;
with lib;
with import ../dependencies.nix { inherit config; }; {
  home.packages = [
    anixpkgs.trafficsim
    anixpkgs.la-quiz
    (writeShellScriptBin "playzelda" ''
      GAMES_DIR="$HOME/games"
      ZELDA_ROM="$GAMES_DIR/LegendOfZeldaCollectorsEdition.iso"
      MEMRY_CRD="$GAMES_DIR/MemoryCardA.USA.raw"
      if [[ ! -d "$GAMES_DIR" ]]; then
          ${anixpkgs.color-prints}/bin/echo_red "Games directory $GAMES_DIR not present. Exiting."
          exit 1
      fi
      ${anixpkgs.color-prints}/bin/echo_cyan "Syncing the Games directory..."
      rclone bisync dropbox:Games ~/games || { ${anixpkgs.color-prints}/bin/echo_red "Sync failed. Exiting."; exit 1; }
      if [[ ! -f "$ZELDA_ROM" ]]; then
          ${anixpkgs.color-prints}/bin/echo_red "Zelda ROM $ZELDA_ROM not present after syncing. Exiting."
          exit 1
      fi
      if [[ ! -f "$MEMRY_CRD" ]]; then
          ${anixpkgs.color-prints}/bin/echo_red "Memory card $MEMRY_CRD not present after syncing. Exiting."
          exit 1
      fi
      # TODO copy from cloud to disk?
      ${pkgs.dolphinEmu}/bin/dolphin-emu -a LLE -e "$ZELDA_ROM"
      # TODO copy from disk to cloud?
      # TODO sync; warn if failed
    '')
  ];
}
