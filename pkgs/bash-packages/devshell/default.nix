{
  bashInteractive,
  writeArgparseScriptBin,
  writeShellScriptBin,
  writeText,
  symlinkJoin,
  python3,
  color-prints,
  setupws,
  editorName ? "code",
}:
let
  pkgname = "devshell";
  usage_str = ''
    usage: ${pkgname} [-n|--new] [-d DEVRC] [-s DEVHIST] [--override-data-dir DIR] [--run CMD] workspace_name

    Enter [workspace_name]'s development shell as defined in ~/.devrc
    (can specify an alternate path with -d DEVRC or history file with
    -s DEVHIST).
    Add a new workspace with the -n|--new flag.
    Optionally run a one-off command with --run CMD (e.g., --run dev).

    Example ~/.devrc:
    =================================================================
    dev_dir = ~/dev
    data_dir = ~/data
    pkgs_dir = ~/sources/anixpkgs
    pkgs_var = <anixpkgs>

    # repositories
    [manif-geom-cpp] = pkgs manif-geom-cpp
    [geometry] = pkgs python3.pkgs.geometry
    [pyvitools] = git@github.com:goromal/pyvitools.git
    [scrape] = git@github.com:goromal/scrape.git

    # scripts
    <script_ref> = data_dir_relative_path/script

    # workspaces
    signals = manif-geom-cpp geometry pyvitools script_ref
    =================================================================
  '';
  printErr = "${color-prints}/bin/echo_red";
  parseScript = ./parseWorkspace.py;
  shellSetupScript = ./setupWsShell.py;
  devScript = ./dev.py;
  selectWsScript = ./selectWorkspace.py;
  setupCurrentWs = writeShellScriptBin "setupcurrentws" ''
    set -e

    rcinfo="''${1:-}"
    if [[ -z "$rcinfo" ]]; then
      if [[ -z "$DEVSHELL_DATA_OVERRIDE" ]]; then
        rcinfo=$(${python3}/bin/python ${parseScript} PARSE "$DEVSHELL_DEVRC" "$DEVSHELL_WSNAME")
      else
        rcinfo=$(${python3}/bin/python ${parseScript} PARSE "$DEVSHELL_DEVRC" "$DEVSHELL_WSNAME" "$DEVSHELL_DATA_OVERRIDE")
      fi
    fi

    if [[ "$rcinfo" == "_NODEVRC_" ]]; then
      ${printErr} "ERROR: no $DEVSHELL_DEVRC file found"
      exit 1
    elif [[ "$rcinfo" == "_NOWSGIVEN_" ]]; then
      ${printErr} "ERROR: no workspace name provided."
      exit 1
    elif [[ "$rcinfo" == ERROR* ]]; then
      ${printErr} "$rcinfo"
      exit 1
    elif [[ "$rcinfo" == "_NOWSFOUND_" ]]; then
      ${printErr} "ERROR: workspace $DEVSHELL_WSNAME not found in $DEVSHELL_DEVRC"
      exit 1
    fi

    IFS='|' read -ra rcinfoarray <<< "$rcinfo"
    dev_dir="''${rcinfoarray[0]}"
    data_dir="''${rcinfoarray[1]}"
    pkgs_var="''${rcinfoarray[2]}"
    rpspecs_list="''${rcinfoarray[3]}"
    sources_list="''${rcinfoarray[4]}"
    scripts_list="''${rcinfoarray[5]}"

    mkdir -p "$dev_dir/$DEVSHELL_WSNAME"
    ${python3}/bin/python ${shellSetupScript} "$dev_dir/$DEVSHELL_WSNAME" "$pkgs_var" $rpspecs_list
    ${setupws}/bin/setupws \
      --dev_dir "$dev_dir" \
      --data_dir "$data_dir" \
      "$DEVSHELL_WSNAME" \
      $sources_list \
      $scripts_list
  '';
  devCommand = writeShellScriptBin "dev" ''
    exec ${python3}/bin/python ${devScript} \
      "$DEVSHELL_WSNAME" \
      "$DEVSHELL_ROOT" \
      "$DEVSHELL_EDITOR" \
      "$DEVSHELL_HISTORY" \
      "$DEVSHELL_DEVRC"
  '';
  addSrc = writeShellScriptBin "addsrc" ''
    if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]] || [[ -z "$1" ]]; then
      echo "addsrc REPONAME [REPOURL]"
      exit
    fi
    ${python3}/bin/python ${parseScript} ADDSRC \
      "$DEVSHELL_WSNAME" "$DEVSHELL_DEVRC" "$1" "$2" && setupcurrentws
  '';
  addScript = writeShellScriptBin "addscr" ''
    if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]] || [[ -z "$1" ]]; then
      echo "addscr SCRIPTNAME [SCRIPTPATH]"
      exit
    fi
    ${python3}/bin/python ${parseScript} ADDSCR \
      "$DEVSHELL_WSNAME" "$DEVSHELL_DEVRC" "$1" "$2" && setupcurrentws
  '';
  runtimeCommands = symlinkJoin {
    name = "devshell-runtime-commands";
    paths = [
      setupCurrentWs
      devCommand
      addSrc
      addScript
    ];
  };
  interactiveRc = writeText "devshell-bashrc" ''
    if [[ -f ~/.bashrc ]]; then
      source ~/.bashrc
    fi
    export PS1='\n\[\033[1;36m\][devshell='"$DEVSHELL_WSNAME"':\w]\$\[\033[0m\] '
    alias godev='cd "$DEVSHELL_ROOT"'
  '';
in
(writeArgparseScriptBin pkgname usage_str
  [
    {
      var = "devrc";
      isBool = false;
      default = "~/.devrc";
      flags = "-d";
    }
    {
      var = "devhist";
      isBool = false;
      default = "~/.devhist";
      flags = "-s";
    }
    {
      var = "overridedatadir";
      isBool = false;
      default = "";
      flags = "--override-data-dir";
    }
    {
      var = "runcmd";
      isBool = false;
      default = "";
      flags = "--run";
    }
    {
      var = "newws";
      isBool = true;
      default = "0";
      flags = "-n|--new";
    }
  ]
  ''
    set -e

    wsname=$1
    if [[ -z "$wsname" ]]; then
        ${printErr} "ERROR: no workspace name provided."
        exit 1
    fi

    if [[ "$newws" == "1" ]]; then
        ${python3}/bin/python ${parseScript} ADDWS "$devrc" $wsname
    fi

    if [[ -z "$overridedatadir" ]]; then
      rcinfo=$(${python3}/bin/python ${parseScript} PARSE "$devrc" $wsname)
    else
      rcinfo=$(${python3}/bin/python ${parseScript} PARSE "$devrc" $wsname "$overridedatadir")
    fi
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
      dev_dir="''${rcinfoarray[0]}"
      export DEVSHELL_WSNAME="$wsname"
      export DEVSHELL_ROOT="$dev_dir/$wsname"
      export DEVSHELL_DEVRC="$devrc"
      export DEVSHELL_DATA_OVERRIDE="$overridedatadir"
      export DEVSHELL_EDITOR=${editorName}
      export DEVSHELL_HISTORY="$devhist"
      export DEVSHELL_RUNTIME_BIN="${runtimeCommands}/bin"
      export PATH="${runtimeCommands}/bin:$PATH"

      setupcurrentws "$rcinfo"
      cd "$DEVSHELL_ROOT"

      if [[ -z "$runcmd" ]]; then
        export DEVSHELL_ACTIVE="$wsname"
        exec ${bashInteractive}/bin/bash --rcfile ${interactiveRc} -i
      else
        unset DEVSHELL_ACTIVE
        exec ${bashInteractive}/bin/bash -c "$runcmd"
      fi
    fi
  ''
)
// {
  inherit selectWsScript;
  meta = {
    description = "Developer tool for creating siloed dev environments.";
    longDescription = ''
      A workspace has the directory tree structure:

      - `[dev_dir]/[workspace_name]`: Workspace root.
        - `data/`: Directory for storing long-lived workspace data, symlinked to `[data_dir]/[workspace_name]`.
        - `.envrc`: `direnv` environment file defining important worksapce aliases.
        - `shell.nix`: Workspace shell file for `lorri` integrations.
        - `sources/`: Directory containing all workspace source repositories.

      The `dev/` directory can be deleted and re-constructed as needed, whereas the `data/` directory holds stuff that's meant to last.

      Once in the shell, the following commands are provided:

      - `setupcurrentws`: A wrapped version of [setupws](./setupws.md) that will build your development workspace as specified in `~/.devrc`.
      - `godev`: An alias that will take you to the root of your development workspace.
      - `listsources`: See the [listsources](./listsources.md) tool documentation.
      - `dev`: Enter an interactive menu for workspace source manipulation.
    '';
    autoGenUsageCmd = "--help";
  };
}
