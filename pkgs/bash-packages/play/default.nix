{
  standalone-opt ? false,
  color-prints,
  writeArgparseScriptBin,
  dolphin-emu,
  pcsx2,
  util-linux,
  coreutils,
  python3,
}:
with import ../../nixos/dependencies.nix;
let
  printErr = "${color-prints}/bin/echo_red";
  printCyn = "${color-prints}/bin/echo_cyan";
  games = import ./games.nix;
  gameNames = builtins.concatStringsSep "\n      " (map (x: "${x.name}\t${x.title}") games);
  gameOpts = builtins.concatStringsSep "\n" (
    map (x: ''
      elif [[ "$1" == "${x.name}" ]]; then
        GAMES_ROM="${x.location}"
        CLOUD_DIR=${x.cloudDir}
        EMULATOR=${x.emulator}
    '') games
  );
  graphicsWrapper =
    if standalone-opt then
      "nix run --override-input nixpkgs nixpkgs/nixos-${nixos-version} --impure github:guibou/nixGL --"
    else
      "";
in
(writeArgparseScriptBin "play"
  ''
    usage: play GAME|setup-ps2

    Play a game. Your options:
          ${gameNames}
          setup-ps2  Configure the PS2 BIOS, controller, and memory cards.
  ''
  [ ]
  ''
    export PATH="${coreutils}/bin:$PATH"
    fail() { ${printErr} "$*"; exit 1; }
    GAMES_DIR="$HOME/games"
    SETUP=0
    if [[ -z "$1" ]]; then
      fail "No game choice provided."
    elif [[ "$1" == "setup-ps2" ]]; then
      EMULATOR=pcsx2
      CLOUD_DIR=games
      SETUP=1
    ${gameOpts}
    else
      fail "Unrecognized game choice: $1"
    fi

    STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/play"
    mkdir -p "$STATE_DIR" || fail "Cannot create $STATE_DIR."
    exec 9>"$STATE_DIR/session.lock"
    ${util-linux}/bin/flock -n 9 || fail "Another play session is already running."
    PENDING="$STATE_DIR/$EMULATOR.pending"
    [[ ! -f "$PENDING" ]] || fail "Previous save transfer was interrupted. See $PENDING before retrying; local cards have been preserved."
    [[ -d "$GAMES_DIR" ]] || fail "Games directory $GAMES_DIR not present."
    ${printCyn} "Syncing the $CLOUD_DIR directory..."
    rcrsync sync "$CLOUD_DIR" || fail "Sync failed."
    if [[ "$SETUP" == 0 ]]; then
      [[ -f "$GAMES_ROM" ]] || fail "Game ROM $GAMES_ROM not present after syncing."
    fi
    if [[ "$CLOUD_DIR" != games ]]; then
      rcrsync sync games || fail "Save sync failed."
    fi

    ps2_cards() {
      ${python3}/bin/python3 - <<'PY'
    import configparser
    import os
    from pathlib import Path
    root = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "PCSX2"
    config = configparser.ConfigParser(interpolation=None, strict=False)
    config.read(root / "inis/PCSX2.ini")
    path = Path(config.get("Folders", "MemoryCards", fallback="memcards"))
    print(path if path.is_absolute() else root / path)
    PY
    }
    if [[ "$EMULATOR" == pcsx2 ]]; then
      CLOUD_SAVE="$GAMES_DIR/ps2/memcards"
      LOCAL_SAVE=$(ps2_cards) || fail "Cannot read PCSX2 memory-card settings."
      mkdir -p "$LOCAL_SAVE" "$(dirname "$CLOUD_SAVE")" || fail "Cannot create card directories."
      COMMAND=(${graphicsWrapper} ${pcsx2}/bin/pcsx2-qt)
      if [[ "$SETUP" == 0 ]]; then
        COMMAND+=(-fullscreen -batch -- "$GAMES_ROM")
      fi
    else
      CLOUD_SAVE="$GAMES_DIR/MemoryCardA.USA.raw"
      LOCAL_SAVE="$HOME/.local/share/dolphin-emu/GC/MemoryCardA.USA.raw"
      [[ -f "$CLOUD_SAVE" ]] || fail "Memory card $CLOUD_SAVE not present after syncing."
      mkdir -p "$(dirname "$LOCAL_SAVE")" || fail "Cannot create Dolphin card directory."
      COMMAND=(${graphicsWrapper} ${dolphin-emu}/bin/dolphin-emu ${
        if standalone-opt then "" else "-a LLE"
      } -e "$GAMES_ROM")
    fi

    # Stage a complete copy before replacing anything; retain the previous copy.
    copy_save() {
      local source="$1" target="$2" stage
      [[ "$source" != "$target" ]] || return 0
      stage=$(mktemp -d "$(dirname "$target")/.play-save.XXXXXX") || return 1
      if ! cp -a "$source" "$stage/save"; then
        rm -rf "$stage"
        return 1
      fi
      if [[ -e "$target" ]]; then
        rm -rf "$target.bak" || return 1
        mv "$target" "$target.bak" || return 1
      fi
      mv "$stage/save" "$target" || return 1
      rmdir "$stage"
    }
    if [[ -e "$CLOUD_SAVE" ]]; then
      copy_save "$CLOUD_SAVE" "$LOCAL_SAVE" || fail "Card restore failed; emulator was not launched."
    fi
    record_pending() {
      printf 'Local cards: %s\nCloud copy: %s\nCopy local cards to the cloud copy, run rcrsync sync games, then remove this file.\n' "$LOCAL_SAVE" "$CLOUD_SAVE" > "$PENDING" || fail "Cannot record save recovery information."
    }
    record_pending

    # Isolate the emulator so Sunshine's group SIGTERM reaches it exactly once,
    # via this wrapper. A second SIGTERM makes PCSX2 exit without cleanup.
    # shellcheck disable=SC2329 # Invoked by the signal trap.
    stop_emulator() {
      trap "" TERM INT
      kill -TERM -- "-$EMU_PID" 2>/dev/null || true
      wait "$EMU_PID"
      EMULATOR_STATUS=$?
    }
    ${printCyn} "Launching $EMULATOR..."
    ${util-linux}/bin/setsid "''${COMMAND[@]}" &
    EMU_PID=$!
    trap stop_emulator TERM INT
    wait "$EMU_PID"
    RESULT=$?
    RESULT=''${EMULATOR_STATUS:-$RESULT}
    trap "" TERM INT
    # Setup may have changed the memory-card directory.
    if [[ "$EMULATOR" == pcsx2 ]]; then
      LOCAL_SAVE=$(ps2_cards) || fail "Cannot read updated memory-card settings."
    fi
    record_pending
    ${printCyn} "Saving memory cards..."
    copy_save "$LOCAL_SAVE" "$CLOUD_SAVE" || fail "Save copy failed. Local cards and recovery marker retained."
    rcrsync sync games || fail "Save upload failed. Local cards and recovery marker retained."
    rm "$PENDING"
    exit "$RESULT"
  ''
)
// {
  meta = {
    description = "Play GameCube and PlayStation 2 games with cloud-synced memory cards.";
    longDescription = ''
      Uses Dolphin or PCSX2 and the shared Sunshine game catalog. Run play setup-ps2
      to select a PS2 BIOS and map the controller during a Moonlight session.
      PS2 cards are synced through ~/games/ps2/memcards; BIOS, settings, and save states stay local.
      Use Sunset Stop for PCSX2 before disconnecting. Force quit can interrupt game saves.
      Interrupted transfers leave recovery instructions in ~/.local/state/play/*.pending.
    '';
    autoGenUsageCmd = "--help";
  };
}
