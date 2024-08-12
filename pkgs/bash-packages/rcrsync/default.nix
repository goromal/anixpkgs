{ cloudDirs ? [ ], writeArgparseScriptBin, rclone, color-prints, redirects
, flock }:
let
  pkgname = "rcrsync";
  description = "Cloud directory management tool.";
  cliCloudList = builtins.concatStringsSep "\n      "
    (map (x: "${x.name}	${x.cloudname}	<->  ${x.dirname}") cloudDirs);
  longDescription = ''
    usage: ${pkgname} [OPTS] [status|init|sync] CLOUD_DIR

    Manage cloud directories with rclone.

    Options:
          -v|--verbose     Print verbose output

    CLOUD_DIR options:

          ${cliCloudList}
  '';
  printErr = ">&2 ${color-prints}/bin/echo_red";
  printYlw = "${color-prints}/bin/echo_yellow";
  printCyn = "${color-prints}/bin/echo_cyan";
  cloudChecks = builtins.concatStringsSep "\n" (map (x: ''
    elif [[ "$2" == "${x.name}" ]] && [[ "$1" == ${
      if x.daemonmode then ''"init" || "$1" == "status"'' else "$1"
    } ]]; then
      CLOUD_DIR="${x.cloudname}"
      LOCAL_DIR="${x.dirname}"
      DAEMON_NAME="${if x.daemonmode then "${x.name}-sync.service" else ""}"
  '') cloudDirs);
in (writeArgparseScriptBin pkgname longDescription [{
  var = "verbose";
  isBool = true;
  default = "0";
  flags = "-v|--verbose"; # ^^^^ TODO handle daemon inits differently
}] ''
  if [[ -z "$1" ]]; then
    ${printErr} "No command provided."
    exit 1
  fi
  if [[ -z "$2" ]]; then
    ${printErr} "No CLOUD_DIR provided."
    exit 1
  ${cloudChecks}
  else
    ${printErr} "Unsupported CLOUD_DIR for command $1: $2"
    exit 1
  fi
  if [[ "$1" == "init" ]]; then
    if [[ -d "$LOCAL_DIR" ]]; then
      ${printYlw} "Local directory $LOCAL_DIR present. Delete it if you wish to start fresh."
      exit
    fi
    ${printCyn} "Copying from $CLOUD_DIR to $LOCAL_DIR..."
    _success=1
    if [[ "$verbose" == "1" ]]; then
      ${rclone}/bin/rclone copy $CLOUD_DIR $LOCAL_DIR ${redirects.stderr_to_stdout} || { _success=0; }
    else
      ${rclone}/bin/rclone copy $CLOUD_DIR $LOCAL_DIR ${redirects.suppress_all} || { _success=0; }
    fi
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
    ${printCyn} "Syncing $CLOUD_DIR and $LOCAL_DIR..."
    _success=1
    if [[ "$verbose" == "1" ]]; then
      ${flock}/bin/flock $LOCAL_DIR -c "${rclone}/bin/rclone bisync $CLOUD_DIR $LOCAL_DIR ${redirects.stderr_to_stdout}" || { _success=0; }
    else
      ${flock}/bin/flock $LOCAL_DIR -c "${rclone}/bin/rclone bisync $CLOUD_DIR $LOCAL_DIR ${redirects.suppress_all}" || { _success=0; }
    fi
    if [[ "$_success" == "0" ]]; then
      ${printYlw} "Bisync failed; attempting with --resync..."
      _success=1
      if [[ "$verbose" == "1" ]]; then
        ${flock}/bin/flock $LOCAL_DIR -c "${rclone}/bin/rclone bisync --resync $CLOUD_DIR $LOCAL_DIR ${redirects.stderr_to_stdout}" || { _success=0; }
      else
        ${flock}/bin/flock $LOCAL_DIR -c "${rclone}/bin/rclone bisync --resync $CLOUD_DIR $LOCAL_DIR ${redirects.suppress_all}" || { _success=0; }
      fi
      if [[ "$_success" == "0" ]]; then
        ${printErr} "Bisync retry failed. Consider running 'rclone config reconnect ''${CLOUD_DIR%%:*}:'. Exiting."
        exit 1
      fi
    fi
    echo "Done."
  elif [[ "$1" == "status" ]]; then
    if [[ ! -z "$DAEMON_NAME" ]]; then
      systemctl --user is-active --quiet "$DAEMON_NAME" && { echo -n "$DAEMON_NAME is "; echo_green "ACTIVE"; } || { echo -n "$DAEMON_NAME is "; echo_red "INACTIVE"; }
    else
      echo -n "$LOCAL_DIR "
      if [ -d "$LOCAL_DIR" ]; then
        echo_green -n "EXISTS "
        echo -n "and "
        if [ "$(ls -A $LOCAL_DIR 2>/dev/null)" ]; then
          echo_green "HAS STUFF IN IT"
        else
          echo_red "IS EMPTY"
        fi
      else
        echo_red "DOES NOT EXIST"
      fi
    fi
  else
    ${printErr} "Unrecognized command: $1"
    exit 1
  fi
'') // {
  meta = {
    inherit description;
    longDescription = "";
    autoGenUsageCmd = "--help";
  };
}
