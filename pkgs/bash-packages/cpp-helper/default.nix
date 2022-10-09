{ writeShellScriptBin
, callPackage
, color-prints
, redirects
}:
let
    pkgname = "cpp-helper";
    argparse = callPackage ../bash-utils/argparse.nix {
        usage_str = ''
        usage: ${pkgname} [options]

        Options:
        --make-format-file       Dumps a format rules file into ./.clang-format
        '';
        optsWithVarsAndDefaults = [
            { var = "makeff"; isBool = true; default = "0"; flags = "--make-format-file"; }
        ];
    };
    printErr = "${color-prints}/bin/echo_red";
    printGrn = "${color-prints}/bin/echo_green";
    formatFile = ./res/clang-format;
    makeffRule = ''
    if [[ "$makeff" == "1" ]]; then
        ${printGrn} "Generating .clang-format..."
        cat ${formatFile} > .clang-format
    fi
    '';
in writeShellScriptBin pkgname ''
    ${argparse}
    ${makeffRule}
''
