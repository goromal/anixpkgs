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
        usage: ${pkgname} workspace_name

        Enter [workspace_name]'s development shell as defined in ~/.devrc

        Example ~/.devrc:
        =================================================================
        dev_dir = ~/dev
        data_dir = ~/data

        # deployments
        <anixpkgs> = ~/sources/anixpkgs

        # repositories
        [manif-geom-cpp] = anixpkgs manif-geom-cpp
        [geometry] = anixpkgs geometry
        [pyvitools] = git@github.com:goromal/pyvitools.git
        [scrape] = git@github.com:goromal/scrape.git

        # workspaces
        signals = manif-geom-cpp geometry pyvitools
        =================================================================
        '';
        optsWithVarsAndDefaults = [];
    };
    printErr = "${color-prints}/bin/echo_red";
    parseScript = ./parseWorkspace.py;
    shellFile = ./mkDevShell.nix;
in writeShellScriptBin pkgname ''
    ${argparse}

    wsname=$1
    if [[ -z "$wsname" ]]; then
        ${printErr} "ERROR: no workspace name provided."
        exit 1
    fi

    rcinfo=$(${python3}/bin/python ${parseScript} $wsname)
    if [[ "$rcinfo" == "_NODEVRC_" ]]; then
        ${printErr} "ERROR: no ~/.devrc file found"
        exit 1
    elif [[ "$rcinfo" == "_NOWSGIVEN_" ]]; then
        ${printErr} "ERROR: no workspace name provided."
        exit 1
    elif [[ "$rcinfo" == "_BADDEVRC_" ]]; then
        ${printErr} "ERROR: mal-formed ~/.devrc"
        exit 1
    elif [[ "$rcinfo" == "_NOWSFOUND_" ]]; then
        ${printErr} "ERROR: workspace $wsname not found in ~/.devrc"
        exit 1
    else
        IFS='|' read -ra rcinfoarray <<< "$rcinfo"
        dev_dir="''${rcinfoarray[0]}"
        data_dir="''${rcinfoarray[1]}"
        sources_list="''${rcinfoarray[2]}"
        nix-shell ${shellFile} \
          --arg setupws ${setupws} \
          --argstr wsname "$wsname" \
          --argstr devDir "$dev_dir" \
          --argstr dataDir "$data_dir" \
          --arg repoSpecList "$sources_list"
    fi
''
