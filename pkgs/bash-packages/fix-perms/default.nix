{ writeShellScriptBin
, callPackage
, color-prints
}:
let
    pkgname = "fix-perms";
    argparse = callPackage ../bash-utils/argparse.nix {
        usage_str = ''
        usage: ${pkgname} dir

        Recursively claim ownership of all files and folders in dir.
        '';
        optsWithVarsAndDefaults = [];
    };
    printErr = "${color-prints}/bin/echo_red";
    printGrn = "${color-prints}/bin/echo_green";
in writeShellScriptBin pkgname ''
    ${argparse}
    if [[ -z "$1" ]]; then
        ${printErr} "No dir provided."
        exit 1
    fi
    find "$1" -type d -exec chmod 755 {} \;
    find "$1" -type f -exec chmod 644 {} \;
    ${printGrn} "Done!"
''
