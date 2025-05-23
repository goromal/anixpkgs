{ cloudDirs ? [ ], homeDir ? "/data/andrew", writeArgparseScriptBin, rclone
, color-prints, redirects, flock, rcloneCfg ? "~/.config/rclone/rclone.conf" }:
let
  pkgname = "rcrsync";
  description = "Cloud directory management tool.";
  cliCloudList = builtins.concatStringsSep "\n      "
    (map (x: "${x.name}	${x.cloudname}	<->  ~/${x.dirname}") cloudDirs);
  longDescription = ''
    usage: ${pkgname} [OPTS] init|sync|copy|override CLOUD_DIR [subdir]

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
    elif [[ "$2" == "${x.name}" ]]; then
      CLOUD_DIR="${x.cloudname}"
      LOCAL_DIR="${homeDir}/${x.dirname}"
  '') cloudDirs);
in (writeArgparseScriptBin pkgname longDescription [{
  var = "verbose";
  isBool = true;
  default = "0";
  flags = "-v|--verbose";
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
    ${printErr} "Unrecognized CLOUD_DIR: $2"
    exit 1
  fi
  if [[ ! -z "$3" ]]; then
    CLOUD_DIR="$CLOUD_DIR/$3"
    LOCAL_DIR="$LOCAL_DIR/$3"
  fi
  if [[ "$1" == "init" ]]; then
    if [[ -d "$LOCAL_DIR" ]]; then
      ${printYlw} "Local directory $LOCAL_DIR present. Delete it if you wish to start fresh."
      exit
    fi
    ${printCyn} "Copying from $CLOUD_DIR to $LOCAL_DIR..."
    _success=1
    if [[ "$verbose" == "1" ]]; then
      ${rclone}/bin/rclone --config ${rcloneCfg} copy $CLOUD_DIR $LOCAL_DIR ${redirects.stderr_to_stdout} || { _success=0; }
    else
      ${rclone}/bin/rclone --config ${rcloneCfg} copy $CLOUD_DIR $LOCAL_DIR ${redirects.suppress_all} || { _success=0; }
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
      ${flock}/bin/flock $LOCAL_DIR -c "${rclone}/bin/rclone --config ${rcloneCfg} bisync $CLOUD_DIR $LOCAL_DIR ${redirects.stderr_to_stdout}" || { _success=0; }
    else
      ${flock}/bin/flock $LOCAL_DIR -c "${rclone}/bin/rclone --config ${rcloneCfg} bisync $CLOUD_DIR $LOCAL_DIR ${redirects.suppress_all}" || { _success=0; }
    fi
    if [[ "$_success" == "0" ]]; then
      ${printYlw} "Bisync failed; attempting with --resync..."
      _success=1
      if [[ "$verbose" == "1" ]]; then
        ${flock}/bin/flock $LOCAL_DIR -c "${rclone}/bin/rclone --config ${rcloneCfg} bisync --resync $CLOUD_DIR $LOCAL_DIR ${redirects.stderr_to_stdout}" || { _success=0; }
      else
        ${flock}/bin/flock $LOCAL_DIR -c "${rclone}/bin/rclone --config ${rcloneCfg} bisync --resync $CLOUD_DIR $LOCAL_DIR ${redirects.suppress_all}" || { _success=0; }
      fi
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
    ${printCyn} "Copying $CLOUD_DIR to $LOCAL_DIR..."
    _success=1
    if [[ "$verbose" == "1" ]]; then
      ${flock}/bin/flock $LOCAL_DIR -c "${rclone}/bin/rclone --config ${rcloneCfg} copy $CLOUD_DIR $LOCAL_DIR ${redirects.stderr_to_stdout}" || { _success=0; }
    else
      ${flock}/bin/flock $LOCAL_DIR -c "${rclone}/bin/rclone --config ${rcloneCfg} copy $CLOUD_DIR $LOCAL_DIR ${redirects.suppress_all}" || { _success=0; }
    fi
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
    ${printCyn} "Overriding $CLOUD_DIR with $LOCAL_DIR..."
    _success=1
    if [[ "$verbose" == "1" ]]; then
      ${flock}/bin/flock $LOCAL_DIR -c "${rclone}/bin/rclone --config ${rcloneCfg} copy $LOCAL_DIR $CLOUD_DIR ${redirects.stderr_to_stdout}" || { _success=0; }
    else
      ${flock}/bin/flock $LOCAL_DIR -c "${rclone}/bin/rclone --config ${rcloneCfg} copy $LOCAL_DIR $CLOUD_DIR ${redirects.suppress_all}" || { _success=0; }
    fi
    if [[ "$_success" == "0" ]]; then
      ${printErr} "Override failed. Consider running 'rclone config reconnect ''${CLOUD_DIR%%:*}:'. Exiting."
      exit 1
    fi
    echo "Done."
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
