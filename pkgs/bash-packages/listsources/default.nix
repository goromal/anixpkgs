{ writeShellScriptBin
, callPackage
, color-prints
}:
let
    pkgname = "listsources";
    argparse = callPackage ../bash-utils/argparse.nix {
        usage_str = ''
        usage: ${pkgname}

        List git information for all sources in a workspace. Must be run 
        within in a workspace created by setupws.
        '';
        optsWithVarsAndDefaults = [];
    };
    printErr = "${color-prints}/bin/echo_red";
    printWht = "${color-prints}/bin/echo_white";
in writeShellScriptBin pkgname ''
    set -e pipefail
    ${argparse}
    if [[ -z "$WSROOT" ]]; then
        ${printErr} "ERROR: \$WSROOT not set. Are you in a directory set up by setupws?"
        exit 1
    fi
    cd "$WSROOT/sources"
    clear
    for proj in *; do
        ${printWht} "======= $proj ======="
        cd $proj
        ${printWht} $(git log | head -1)
        git status
        cd ..
        echo ""
    done
''
