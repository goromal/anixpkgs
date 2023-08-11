{ writeShellScriptBin
, python3
, callPackage
, color-prints
, setupws
}:
let
    pkgname = "devshell";
    argparse = callPackage ../bash-utils/argparse.nix {
        usage_str = ''
        usage: ${pkgname} [-d DEVRC] [--run CMD] workspace_name

        Enter [workspace_name]'s development shell as defined in ~/.devrc
        (can specify an alternate path with -d DEVRC).
        Optionally run a one-off command with --run CMD.

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

        # workspaces
        signals = manif-geom-cpp geometry pyvitools
        =================================================================
        '';
        optsWithVarsAndDefaults = [
            { var = "devrc"; isBool = false; default = "~/.devrc"; flags = "-d"; }
            { var = "runcmd"; isBool = false; default = ""; flags = "--run"; }
        ];
    };
    printErr = "${color-prints}/bin/echo_red";
    parseScript = ./parseWorkspace.py;
    shellFile = ./mkDevShell.nix;
    shellSetupScript = ./setupWsShell.py;
in (writeShellScriptBin pkgname ''
    ${argparse}

    wsname=$1
    if [[ -z "$wsname" ]]; then
        ${printErr} "ERROR: no workspace name provided."
        exit 1
    fi

    runargstr=""
    if [[ ! -z "$runcmd" ]]; then
        runargstr="--run \"''${runcmd}\""
    fi

    rcinfo=$(${python3}/bin/python ${parseScript} "$devrc" $wsname)
    if [[ "$rcinfo" == "_NODEVRC_" ]]; then
        ${printErr} "ERROR: no $devrc file found"
        exit 1
    elif [[ "$rcinfo" == "_NOWSGIVEN_" ]]; then
        ${printErr} "ERROR: no workspace name provided."
        exit 1
    elif [[ "$rcinfo" == "_BADDEVRC_" ]]; then
        ${printErr} "ERROR: mal-formed $devrc"
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
        if [[ -z "$runcmd"  ]]; then
            nix-shell ${shellFile} \
              --arg setupws ${setupws} \
              --argstr wsname "$wsname" \
              --argstr devDir "$dev_dir" \
              --argstr dataDir "$data_dir" \
              --argstr pkgsVar "$pkgs_var" \
              --arg shellSetupScript ${shellSetupScript} \
              --arg repoSpecList "$sources_list"
        else
            nix-shell ${shellFile} \
              --arg setupws ${setupws} \
              --argstr wsname "$wsname" \
              --argstr devDir "$dev_dir" \
              --argstr dataDir "$data_dir" \
              --argstr pkgsVar "$pkgs_var" \
              --arg shellSetupScript ${shellSetupScript} \
              --arg repoSpecList "$sources_list" \
              --run "$runcmd"
        fi 
    fi
'') // {
    meta = {
        description = "Developer tool for creating siloed dev environments.";
        longDescription = ''
        ```
        usage: devshell workspace_name

        Enter [workspace_name]'s development shell as defined in ~/.devrc

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

        # workspaces
        signals = manif-geom-cpp geometry pyvitools
        =================================================================
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
        '';
    };
}
