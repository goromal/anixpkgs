{ writeShellScriptBin, callPackage, rclone, color-prints, redirects }:
let
  pkgname = "rcrsync";
  description = "Cloud directory management tool.";
  longDescription = ''
    usage: ${pkgname} [init|sync] CLOUD_DIR

    Manage cloud directories with rclone.

    CLOUD_DIR options:

      configs       dropbox:configs  <->  ~/configs
      secrets       dropbox:secrets  <->  ~/secrets
      games         dropbox:Games    <->  ~/games
      data          box:data         <->  ~/data
      documents     drive:Documents  <->  ~/Documents
  '';
  argparse = callPackage ../bash-utils/argparse.nix {
    usage_str = "${longDescription}";
    optsWithVarsAndDefaults = [ ];
  };
  printErr = ">&2 ${color-prints}/bin/echo_red";
  printYlw = "${color-prints}/bin/echo_yellow";
  printCyn = "${color-prints}/bin/echo_cyan";
in (writeShellScriptBin pkgname ''
  ${argparse}
  if [[ -z "$1" ]]; then
    ${printErr} "No command provided."
    exit 1
  fi
  if [[ -z "$2" ]]; then
    ${printErr} "No CLOUD_DIR provided."
    exit 1
  fi

  if [[ "$2" == "configs" ]]; then
    CLOUD_DIR="dropbox:configs"
    LOCAL_DIR="$HOME/configs"
  elif [[ "$2" == "secrets" ]]; then
    CLOUD_DIR="dropbox:secrets"
    LOCAL_DIR="$HOME/secrets"
  elif [[ "$2" == "games" ]]; then
    CLOUD_DIR="dropbox:Games"
    LOCAL_DIR="$HOME/games"
  elif [[ "$2" == "data" ]]; then
    CLOUD_DIR="box:data"
    LOCAL_DIR="$HOME/data"
  elif [[ "$2" == "documents" ]]; then
    CLOUD_DIR="drive:Documents"
    LOCAL_DIR="$HOME/Documents"
  else
    ${printErr} "Unrecognized CLOUD_DIR: $2"
    exit 1
  fi

  if [[ "$1" == "init" ]]; then
    if [[ -d "$LOCAL_DIR" ]]; then
      ${printYlw} "Local directory $LOCAL_DIR present. Delete it if you wish to start fresh."
      exit
    fi
    ${printCyn} "Copying from $CLOUD_DIR to $LOCAL_DIR..."
    _success=1
    ${rclone}/bin/rclone copy "$CLOUD_DIR" "$LOCAL_DIR" ${redirects.suppress_all} || { _success=0; }
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
    ${rclone}/bin/rclone bisync $CLOUD_DIR "$LOCAL_DIR" ${redirects.suppress_all} || { _success=0; }
    if [[ "$_success" == "0" ]]; then
      ${printYlw} "Bisync failed; attempting with --resync..."
      _success=1
      ${rclone}/bin/rclone bisync --resync $CLOUD_DIR "$LOCAL_DIR" ${redirects.suppress_all} || { _success=0; }
      if [[ "$_success" == "0" ]]; then
        ${printErr} "Bisync retry failed. Exiting."
        exit 1
      fi
    fi
    echo "Done."
  else
    ${printErr} "Unrecognized command: $1"
    exit 1
  fi
'') // {
  meta = {
    inherit description;
    longDescription = ''
      ```bash
      ${longDescription}
      ```
    '';
  };
}
