{
  cloudDirs ? [ ],
  homeDir ? "/data/andrew",
  writeArgparseScriptBin,
  rclone,
  color-prints,
  flock,
  coreutils,
  gnugrep,
  rcloneCfg ? "~/.config/rclone/rclone.conf",
  historyFile ? "${homeDir}/.local/state/rcrsync/history.jsonl",
}:
let
  pkgname = "rcrsync";
  description = "Cloud directory management tool.";
  cliCloudList = builtins.concatStringsSep "\n      " (
    map (x: "${x.name}	${x.cloudname}	<->  ~/${x.dirname}") cloudDirs
  );
  longDescription = ''
    usage: ${pkgname} [OPTS] init|sync|copy|override|mirror CLOUD_DIR [subdir]

    Manage cloud directories with rclone.

    Options:
          -v|--verbose     Print verbose output

    CLOUD_DIR options:

          ${cliCloudList}
  '';
  printErr = ">&2 ${color-prints}/bin/echo_red";
  printYlw = "${color-prints}/bin/echo_yellow";
  printCyn = "${color-prints}/bin/echo_cyan";
  cloudChecks = builtins.concatStringsSep "\n" (
    map (x: ''
      elif [[ "$2" == "${x.name}" ]]; then
        CLOUD_DIR="${x.cloudname}"
        LOCAL_DIR="${homeDir}/${x.dirname}"
    '') cloudDirs
  );
in
(writeArgparseScriptBin pkgname longDescription
  [
    {
      var = "verbose";
      isBool = true;
      default = "0";
      flags = "-v|--verbose";
    }
  ]
  ''
    if [[ -z "$1" ]]; then
      ${printErr} "No command provided."
      exit 1
    fi
    if [[ -z "$2" ]]; then
      ${printErr} "No CLOUD_DIR provided."
      exit 1
    ${cloudChecks}
    else
      ${printErr} "Unrecognized CLOUD_DIR: $2"
      exit 1
    fi
    if [[ ! -z "$3" ]]; then
      CLOUD_DIR="$CLOUD_DIR/$3"
      LOCAL_DIR="$LOCAL_DIR/$3"
    fi

    _VFLAG=""
    if [[ "$verbose" == "1" ]]; then
      _VFLAG="-vvv"
    fi

    _RCLONE_OUT=$(${coreutils}/bin/mktemp)

    # Each attempted transfer appends one JSON line to the history file (read
    # by rcrsync_ui). Set _RECORD_OP right before the transfer starts so that
    # validation errors and declined prompts are not recorded.
    _RECORD_OP=""
    _json_str() {
      local s="''${1//\\/\\\\}"
      printf '"%s"' "''${s//\"/\\\"}"
    }
    _on_exit() {
      local rc=$?
      rm -f "$_RCLONE_OUT"
      if [[ -n "$_RECORD_OP" ]]; then
        local ok=false
        [[ $rc -eq 0 ]] && ok=true
        {
          ${coreutils}/bin/mkdir -p "$(${coreutils}/bin/dirname "${historyFile}")" &&
            printf '{"ts":%s,"op":%s,"dir":%s,"subdir":%s,"ok":%s,"host":%s}\n' \
              "$(${coreutils}/bin/date +%s)" "$(_json_str "$_RECORD_OP")" "$(_json_str "$_DIR_NAME")" \
              "$(_json_str "$_SUBDIR")" "$ok" "$(_json_str "$(${coreutils}/bin/uname -n)")" >>"${historyFile}"
        } 2>/dev/null || ${printYlw} "Warning: could not record history in ${historyFile}"
      fi
      return $rc
    }
    trap _on_exit EXIT
    _DIR_NAME="$2"
    _SUBDIR="$3"

    _run() {
      if [[ "$verbose" == "1" ]]; then
        "$@" 2>&1 | ${coreutils}/bin/tee "$_RCLONE_OUT"
        return ''${PIPESTATUS[0]}
      fi
      "$@" >"$_RCLONE_OUT" 2>&1
    }

    _run_with_reconnect() {
      _run "$@"
      local rc=$?
      if [[ $rc -ne 0 ]] && ${gnugrep}/bin/grep -q "config reconnect" "$_RCLONE_OUT"; then
        local base="''${CLOUD_DIR%%:*}"
        ${printYlw} "Detected rclone reconnect prompt; running 'rclone config reconnect $base:'..."
        if ${rclone}/bin/rclone --config ${rcloneCfg} config reconnect "$base:"; then
          ${printCyn} "Reconnect succeeded; retrying..."
          _run "$@"
          rc=$?
        fi
      fi
      return $rc
    }

    if [[ "$1" == "init" ]]; then
      if [[ -d "$LOCAL_DIR" ]]; then
        ${printYlw} "Local directory $LOCAL_DIR present."
        read -rp "Proceed anyway with a fresh download? (y|n): " DO_INIT
        if [[ "$DO_INIT" != "y" ]]; then
          exit
        fi
        sudo rm -rf "$LOCAL_DIR"
      fi
      _RECORD_OP=init
      ${printCyn} "Copying from $CLOUD_DIR to $LOCAL_DIR..."
      _success=1
      _run_with_reconnect ${rclone}/bin/rclone $_VFLAG --config ${rcloneCfg} copy $CLOUD_DIR $LOCAL_DIR || { _success=0; }
      if [[ "$_success" == "0" ]]; then
        ${printErr} "rclone copy failed. Check rclone!"
        exit 1
      fi
      echo "Done."
    elif [[ "$1" == "sync" ]]; then
      if [[ ! -d "$LOCAL_DIR" ]]; then
        ${printErr} "Local directory $LOCAL_DIR not present. Exiting."
        exit 1
      fi
      _RECORD_OP=sync
      ${printCyn} "Syncing $CLOUD_DIR and $LOCAL_DIR..."
      _success=1
      _run_with_reconnect ${flock}/bin/flock $LOCAL_DIR -c "${rclone}/bin/rclone $_VFLAG --config ${rcloneCfg} bisync $CLOUD_DIR $LOCAL_DIR" || { _success=0; }
      if [[ "$_success" == "0" ]]; then
        ${printYlw} "Bisync failed; attempting with --resync..."
        _success=1
        _run_with_reconnect ${flock}/bin/flock $LOCAL_DIR -c "${rclone}/bin/rclone $_VFLAG --config ${rcloneCfg} bisync --resync $CLOUD_DIR $LOCAL_DIR" || { _success=0; }
        if [[ "$_success" == "0" ]]; then
          ${printErr} "Bisync retry failed. Consider running 'rclone config reconnect ''${CLOUD_DIR%%:*}:'. Exiting."
          exit 1
        fi
      fi
      echo "Done."
    elif [[ "$1" == "copy" ]]; then
      if [[ ! -d "$LOCAL_DIR" ]]; then
        ${printErr} "Local directory $LOCAL_DIR not present. Exiting."
        exit 1
      fi
      _RECORD_OP=copy
      ${printCyn} "Copying $CLOUD_DIR to $LOCAL_DIR..."
      _success=1
      _run_with_reconnect ${flock}/bin/flock $LOCAL_DIR -c "${rclone}/bin/rclone $_VFLAG --config ${rcloneCfg} copy $CLOUD_DIR $LOCAL_DIR" || { _success=0; }
      if [[ "$_success" == "0" ]]; then
        ${printErr} "Copy failed. Consider running 'rclone config reconnect ''${CLOUD_DIR%%:*}:'. Exiting."
        exit 1
      fi
      echo "Done."
    elif [[ "$1" == "override" ]]; then
      if [[ ! -d "$LOCAL_DIR" ]]; then
        ${printErr} "Local directory $LOCAL_DIR not present. Exiting."
        exit 1
      fi
      _RECORD_OP=override
      ${printCyn} "Overriding $CLOUD_DIR with $LOCAL_DIR..."
      _success=1
      _run_with_reconnect ${flock}/bin/flock $LOCAL_DIR -c "${rclone}/bin/rclone $_VFLAG --config ${rcloneCfg} copy $LOCAL_DIR $CLOUD_DIR" || { _success=0; }
      if [[ "$_success" == "0" ]]; then
        ${printErr} "Override failed. Consider running 'rclone config reconnect ''${CLOUD_DIR%%:*}:'. Exiting."
        exit 1
      fi
      echo "Done."
    elif [[ "$1" == "mirror" ]]; then
      if [[ ! -d "$LOCAL_DIR" ]]; then
        ${printErr} "Local directory $LOCAL_DIR not present. Exiting."
        exit 1
      fi
      _RECORD_OP=mirror
      ${printCyn} "Mirroring $LOCAL_DIR to $CLOUD_DIR (deleting extraneous cloud files)..."
      _success=1
      _run_with_reconnect ${flock}/bin/flock $LOCAL_DIR -c "${rclone}/bin/rclone $_VFLAG --config ${rcloneCfg} sync $LOCAL_DIR $CLOUD_DIR" || { _success=0; }
      if [[ "$_success" == "0" ]]; then
        ${printErr} "Mirror failed. Consider running 'rclone config reconnect ''${CLOUD_DIR%%:*}:'. Exiting."
        exit 1
      fi
      echo "Done."
    else
      ${printErr} "Unrecognized command: $1"
      exit 1
    fi
  ''
)
// {
  meta = {
    inherit description;
    longDescription = "";
    autoGenUsageCmd = "--help";
  };
}
