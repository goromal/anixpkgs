{ writeArgparseScriptBin, python3, color-prints, setupws, editorName ? "codium"
}:
let
  pkgname = "devshell";
  usage_str = ''
    usage: ${pkgname} [-d DEVRC] [-s DEVHIST] [--override-data-dir DIR] [--run CMD] workspace_name

    Enter [workspace_name]'s development shell as defined in ~/.devrc
    (can specify an alternate path with -d DEVRC or history file with
    -s DEVHIST).
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
  shellFile = ./mkDevShell.nix;
  shellSetupScript = ./setupWsShell.py;
  devScript = ./dev.py;
in (writeArgparseScriptBin pkgname usage_str [
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
] ''
  wsname=$1
  if [[ -z "$wsname" ]]; then
      ${printErr} "ERROR: no workspace name provided."
      exit 1
  fi

  if [[ -z "$overridedatadir" ]]; then
    rcinfo=$(${python3}/bin/python ${parseScript} "$devrc" $wsname)
  else
    rcinfo=$(${python3}/bin/python ${parseScript} "$devrc" $wsname "$overridedatadir")
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
      data_dir="''${rcinfoarray[1]}"
      pkgs_var="''${rcinfoarray[2]}"
      sources_list="''${rcinfoarray[3]}"
      scripts_list="''${rcinfoarray[4]}"
      if [[ -z "$runcmd" ]]; then
          nix-shell ${shellFile} \
            --arg setupws ${setupws} \
            --argstr wsname "$wsname" \
            --argstr devDir "$dev_dir" \
            --argstr dataDir "$data_dir" \
            --argstr pkgsVar "$pkgs_var" \
            --argstr editorName ${editorName} \
            --arg shellSetupScript ${shellSetupScript} \
            --arg devScript ${devScript} \
            --argstr devHistFile "$devhist" \
            --arg repoSpecList "$sources_list" \
            --arg scriptsList "$scripts_list"
      else
          nix-shell ${shellFile} \
            --arg setupws ${setupws} \
            --argstr wsname "$wsname" \
            --argstr devDir "$dev_dir" \
            --argstr dataDir "$data_dir" \
            --argstr pkgsVar "$pkgs_var" \
            --argstr editorName ${editorName} \
            --arg shellSetupScript ${shellSetupScript} \
            --arg devScript ${devScript} \
            --argstr devHistFile "$devhist" \
            --arg repoSpecList "$sources_list" \
            --arg scriptsList "$scripts_list" \
            --command "$runcmd"
      fi 
  fi
'') // {
  meta = {
    description = "Developer tool for creating siloed dev environments.";
    longDescription = ''
      ```
      ${usage_str}
      ```

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
  };
}
