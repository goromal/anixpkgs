{ writeShellScriptBin
, callPackage
, color-prints
, name
, extension
, usage_str
, optsWithVarsAndDefaults
, convOptCmds
}:
let
    argparse = callPackage ../bash-utils/argparse.nix {
        inherit usage_str optsWithVarsAndDefaults;
    };
    conv_opt_list = map (x: ''
        ${x.extension})
        echo "$infile -> $outfile ..."
        ${x.commands}
        ;;
    '') convOptCmds;
    conv_opt_cmds = builtins.concatStringsSep "\n" conv_opt_list;
    # TODO check extension logic below
in writeShellScriptBin name ''
    ${argparse.cmd}
    infile="$1"
    infile_ext="''${1##*/}"
    outfile="''${2%.*}.${extension}"
    case $infile_ext in
    ${conv_opt_cmds}
    *)
    ${color-prints}/bin/echo_red "ERROR: unhandled input extension ($infile_ext)."
    cat << EOF
    ${usage_str}
    EOF
    ;;
    esac
''