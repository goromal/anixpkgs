{ standalone-opt ? false, callPackage, color-prints, writeArgparseScriptBin
, dolphinEmu }:
with import ../../nixos/dependencies.nix;
let
  pkgname = "play";
  printErr = "${color-prints}/bin/echo_red";
  printCyn = "${color-prints}/bin/echo_cyan";
  printYlw = "${color-prints}/bin/echo_yellow";
  games = [
    {
      name = "zelda";
      description = "Legend of Zelda: Collector's Edition.";
      location = "$HOME/games/LegendOfZeldaCollectorsEdition.iso";
      cloudDir = "games";
    }
    {
      name = "windwaker";
      description = "The Wind Waker.";
      location = "$HOME/more-games/WindWaker.iso";
      cloudDir = "games2";
    }
    {
      name = "twilight";
      description = "Twilight Princess.";
      location = "$HOME/more-games/TwilightPrincess.iso";
      cloudDir = "games2";
    }
    {
      name = "melee";
      description = "Super Smash Bros. Melee.";
      location = "$HOME/more-games/Melee.iso";
      cloudDir = "games2";
    }
    {
      name = "sunshine";
      description = "Super Mario Sunshine.";
      location = "$HOME/more-games/SuperMarioSunshine.iso";
      cloudDir = "games2";
    }
  ];
  gameNames = builtins.concatStringsSep "\n      "
    (map (x: "${x.name}	${x.description}") games);
  gameOpts = builtins.concatStringsSep "\n" (map (x: ''
    elif [[ "$1" == "${x.name}" ]]; then
      GAMES_ROM="${x.location}"
      CLOUD_DIR=${x.cloudDir}
  '') games);
in (writeArgparseScriptBin pkgname ''
  usage: ${pkgname} GAME

  Play a game. Your options:
        ${gameNames}
'' [ ] ''
  GAMES_DIR="$HOME/games"
  MEMRY_CRD="$GAMES_DIR/MemoryCardA.USA.raw"
  MMCRD_DSK="$HOME/.local/share/dolphin-emu/GC/MemoryCardA.USA.raw"
  if [[ -z "$1" ]]; then
    ${printErr} "No game choice provided."
    exit 1
  ${gameOpts}
  else
    ${printErr} "Unrecognized game choice: $1"
    exit 1
  fi
  if [[ ! -d "$GAMES_DIR" ]]; then
      ${printErr} "Games directory $GAMES_DIR not present. Exiting."
      exit 1
  fi
  ${printCyn} "Syncing the $CLOUD_DIR directory..."
  rcrsync sync $CLOUD_DIR || { ${printErr} "Sync failed. Exiting."; exit 1; }
  if [[ ! -f "$GAMES_ROM" ]]; then
      ${printErr} "Game ROM $GAMES_ROM not present after syncing. Exiting."
      exit 1
  fi
  if [[ "$CLOUD_DIR" != "games" ]]; then
    ${printCyn} "Syncing the games directory separately to update the memory card..."
    rcrsync sync games || { ${printErr} "Sync failed. Exiting."; exit 1; }
  fi
  if [[ ! -f "$MEMRY_CRD" ]]; then
      ${printErr} "Memory card $MEMRY_CRD not present after syncing. Exiting."
      exit 1
  fi
  ${printCyn} "Copying memory card from cloud to disk..."
  if [[ -f "$MMCRD_DSK" ]]; then
      mv "$MMCRD_DSK" "''${MMCRD_DSK}.bak"
  fi
  cp "$MEMRY_CRD" "$MMCRD_DSK" || { ${printYlw} "WARNING: Copy failed!"; }
  ${printCyn} "Launching the emulator..."
  ${if standalone-opt then
    "nix run --override-input nixpkgs nixpkgs/nixos-${nixos-version} --impure github:guibou/nixGL -- ${dolphinEmu}/bin/dolphin-emu -e $GAMES_ROM"
  else
    "${dolphinEmu}/bin/dolphin-emu -a LLE -e $GAMES_ROM"}
  ${printCyn} "Copying memory card from disk to cloud..."
  cp "$MMCRD_DSK" "$MEMRY_CRD" || { ${printYlw} "WARNING: Copy failed!"; }
  ${printCyn} "Syncing the Games directory..."
  rcrsync sync games || { ${printYlw} "WARNING: Sync failed!"; }
'') // {
  meta = {
    description = "Play a game using the Dolphin Emulator.";
    longDescription = "";
    autoGenUsageCmd = "--help";
  };
}
