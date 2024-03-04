{ pkgs, config, lib, ... }:
with pkgs;
with lib;
with import ../dependencies.nix { inherit config; };
let cfg = config.mods.opts;
in {
  home.packages = [
    anixpkgs.trafficsim
    anixpkgs.la-quiz
    (writeShellScriptBin "playzelda" ''
      GAMES_DIR="$HOME/games"
      ZELDA_ROM="$GAMES_DIR/LegendOfZeldaCollectorsEdition.iso"
      MEMRY_CRD="$GAMES_DIR/MemoryCardA.USA.raw"
      MMCRD_DSK="$HOME/.local/share/dolphin-emu/GC/MemoryCardA.USA.raw"
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
      ${anixpkgs.color-prints}/bin/echo_cyan "Copying memory card from cloud to disk..."
      if [[ -f "$MMCRD_DSK" ]]; then
          mv "$MMCRD_DSK" "''${MMCRD_DSK}.bak"
      fi
      cp "$MEMRY_CRD" "$MMCRD_DSK" || { ${anixpkgs.color-prints}/bin/echo_yellow "WARNING: Copy failed!"; }
      ${anixpkgs.color-prints}/bin/echo_cyan "Launching the emulator..."
      ${if cfg.standalone then
        "nix run --override-input nixpkgs nixpkgs/nixos-${nixos-version} --impure github:guibou/nixGL -- ${pkgs.dolphinEmu}/bin/dolphin-emu -e $ZELDA_ROM"
      else
        "${pkgs.dolphinEmu}/bin/dolphin-emu -a LLE -e $ZELDA_ROM"}
      ${anixpkgs.color-prints}/bin/echo_cyan "Copying memory card from disk to cloud..."
      cp "$MMCRD_DSK" "$MEMRY_CRD" || { ${anixpkgs.color-prints}/bin/echo_yellow "WARNING: Copy failed!"; }
      ${anixpkgs.color-prints}/bin/echo_cyan "Syncing the Games directory..."
      rclone bisync dropbox:Games ~/games || { ${anixpkgs.color-prints}/bin/echo_yellow "WARNING: Sync failed!"; }
    '')
  ] ++ lib.mkIf (cfg.standalone == false) [
    sage
    pavucontrol # compatible with pipewire-pulse
  ];
}
