{ writeShellScriptBin
, callPackage
, color-prints
}:
let
    default-dev-dir  = "~/dev";
    default-data-dir = "~/data";

    argparse = callPackage ../bash-utils/argparse.nix {
        usage_str = ''
        usage: setupws [OPTIONS] workspace_name srcname:git_url [srcname:git_url ...]

        Create a development workspace with specified git sources.

        Options:
            --dev_dir [DIRNAME]        Specify the root directory where the [workspace_name] source
                                       directory will be created (default: ${default-dev-dir})

            --data_dir [DIRNAME]       Specify the root directory where the [workspace_name] mutable 
                                       data will be stored (default: ${default-data-dir})
        '';
        optsWithVarsAndDefaults = [
            {
                var = "dev_dir";
                isBool = false;
                default = default-dev-dir;
                flags = "--dev_dir";
            }
            {
                var = "data_dir";
                isBool = false;
                default = default-data-dir;
                flags = "--data_dir";
            }
        ];
    };

    printErr = "${color-prints}/bin/echo_red";
    printYlw = "${color-prints}/bin/echo_yellow";
    printGrn = "${color-prints}/bin/echo_green";
in writeShellScriptBin "setupws" ''
    ${argparse}

    set -euo pipefail

    wsname=$1
    if [[ -z "$wsname" ]]; then
        ${printErr} "ERROR: no workspace name provided."
        exit 1
    fi

    ${printYlw} "Setting up workspace $wsname..."
    dev_ws_dir=$dev_dir/$wsname
    data_ws_dir=$data_dir/$wsname

    mkdir -p $dev_ws_dir
    mkdir -p $data_ws_dir

    cd $dev_ws_dir

    if [[ ! -d data ]]; then
        ln -s $data_ws_dir data
    fi
    if [[ ! -d sources ]]; then
        mkdir sources
    fi

    if [[ ! -f .envrc ]]; then
        echo "export WSROOT=$dev_ws_dir" > .envrc
        lorri init
        echo 'eval "$(lorri direnv)"' >> .envrc
        direnv allow
    fi

    cd sources
    
    for i in ''${@:2}; do
        reponame="''${i%%:*}"
        repourl="''${i#*:}"

        if [[ ! -d $reponame ]]; then
            ${printYlw} "Cloning and setting up $reponame..."
            git clone --recurse-submodules "$repourl" "$reponame"
        fi
    done

    ${printGrn} "Done"
''
