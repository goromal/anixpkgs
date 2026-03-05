{
  pkgs ? import <nixpkgs> { },
  printErr,
  setupws,
  wsname,
  devDir,
  dataDir,
  pkgsVar,
  devrcFile,
  devScript,
  parseScript,
  editorName,
  shellSetupScript,
  devHistFile,
}:
let
  setupcurrentws = pkgs.writeShellScriptBin "setupcurrentws" ''
    mkdir -p ${devDir}/${wsname}
    rcinfo=$(${pkgs.python3}/bin/python ${parseScript} PARSE ${devrcFile} ${wsname})
    if [[ "$rcinfo" == "_NODEVRC_" ]]; then
        ${printErr} "ERROR: no $devrc file found"
        exit 1
    elif [[ "$rcinfo" == "_NOWSGIVEN_" ]]; then
        ${printErr} "ERROR: no workspace name provided."
        exit 1
    elif [[ "$rcinfo" == ERROR* ]]; then
        ${printErr} "''${rcinfo}"
        exit 1
    elif [[ "$rcinfo" == "_NOWSFOUND_" ]]; then
        ${printErr} "ERROR: workspace $wsname not found in $devrc"
        exit 1
    else
        IFS='|' read -ra rcinfoarray <<< "$rcinfo"
        rpspecs_list="''${rcinfoarray[3]}"
        sources_list="''${rcinfoarray[4]}"
        scripts_list="''${rcinfoarray[5]}"
        ${pkgs.python3}/bin/python ${shellSetupScript} ${devDir}/${wsname} '${pkgsVar}' $rpspecs_list
        ${setupws}/bin/setupws --dev_dir ${devDir} --data_dir ${dataDir} ${wsname} $sources_list $scripts_list
    fi
  '';
  dev = pkgs.writeShellScriptBin "dev" ''
    ${pkgs.python3}/bin/python ${devScript} ${wsname} ${devDir}/${wsname} ${editorName} ${devHistFile}
  '';
  addsrc = pkgs.writeShellScriptBin "addsrc" ''
    if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
      echo "addsrc REPONAME [REPOURL]"
      exit
    fi
    if [[ -z "$1" ]]; then
      echo "addsrc REPONAME [REPOURL]"
      exit
    fi
    ${pkgs.python3}/bin/python ${parseScript} ADDSRC ${wsname} ${devrcFile} "$1" "$2" && setupcurrentws
  '';
  addscr = pkgs.writeShellScriptBin "addscr" ''
    if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
      echo "addscr SCRIPTNAME [SCRIPTPATH]"
      exit
    fi
    if [[ -z "$1" ]]; then
      echo "addsrc SCRIPTNAME [SCRIPTPATH]"
      exit
    fi
    ${pkgs.python3}/bin/python ${parseScript} ADDSCR ${wsname} ${devrcFile} "$1" "$2" && setupcurrentws
  '';
in
pkgs.mkShell {
  nativeBuildInputs = [
    setupcurrentws
    dev
    addsrc
    addscr
  ];
  shellHook = ''
    export PS1='\n\[\033[1;36m\][devshell=${wsname}:\w]\$\[\033[0m\] '
    alias godev='cd ${devDir}/${wsname}'
    setupcurrentws
    cd ${devDir}/${wsname}

    # Start beads daemon if available and config exists
    if command -v bd &> /dev/null && [ -f sources/.beads.yml ]; then
      BEADS_LOCK_FILE="${devDir}/${wsname}/data/.beads/shell_count"
      mkdir -p "$(dirname "$BEADS_LOCK_FILE")"

      # Check if daemon is actually running
      cd sources
      DAEMON_RUNNING=0
      if bd daemon status &> /dev/null; then
        DAEMON_RUNNING=1
      fi
      cd ..

      # If lock file exists but daemon is not running, reset the lock file
      if [ -f "$BEADS_LOCK_FILE" ] && [ "$DAEMON_RUNNING" -eq 0 ]; then
        echo "Detected stale lock file (daemon not running), resetting..."
        rm -f "$BEADS_LOCK_FILE"
      fi

      # Increment shell count
      if [ -f "$BEADS_LOCK_FILE" ]; then
        SHELL_COUNT=$(cat "$BEADS_LOCK_FILE")
      else
        SHELL_COUNT=0
      fi
      SHELL_COUNT=$((SHELL_COUNT + 1))
      echo "$SHELL_COUNT" > "$BEADS_LOCK_FILE"

      # Start daemon if needed
      if [ "$DAEMON_RUNNING" -eq 0 ]; then
        cd sources
        echo "Starting beads daemon for workspace ${wsname}..."
        if ! bd daemon start 2>&1; then
          echo "Warning: Failed to start beads daemon"
        fi
        cd ..
      fi
    fi

    # Stop beads daemon on shell exit (only if last shell)
    cleanup_beads() {
      if command -v bd &> /dev/null && [ -f ${devDir}/${wsname}/sources/.beads.yml ]; then
        BEADS_LOCK_FILE="${devDir}/${wsname}/data/.beads/shell_count"

        if [ -f "$BEADS_LOCK_FILE" ]; then
          SHELL_COUNT=$(cat "$BEADS_LOCK_FILE")
          SHELL_COUNT=$((SHELL_COUNT - 1))

          if [ "$SHELL_COUNT" -le 0 ]; then
            # Last shell exiting, stop the daemon
            cd ${devDir}/${wsname}/sources
            if bd daemon status &> /dev/null; then
              echo "Stopping beads daemon for workspace ${wsname}..."
              bd daemon stop 2>/dev/null
            fi
            rm -f "$BEADS_LOCK_FILE"
          else
            # Other shells still active, just decrement count
            echo "$SHELL_COUNT" > "$BEADS_LOCK_FILE"
          fi
        fi
      fi
    }
    trap cleanup_beads EXIT
  '';
}
