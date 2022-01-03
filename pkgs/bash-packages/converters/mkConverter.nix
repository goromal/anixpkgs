{ writeShellScriptBin
, callPackage
, color-prints
, strings
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
    printerr = "${color-prints}/bin/echo_red";
    printusage = ''
    cat << EOF
    ${usage_str}
    EOF
    '';
    # TODO check extension logic below
in writeShellScriptBin name ''
    ${argparse.cmd}
    infile="$1"
    if [[ -z "$infile" ]]; then
        ${printerr} "ERROR: no input file specified."
        ${printusage}
        exit
    fi
    infile_ext="''${1##*/}"
    outfile="''${2%.*}.${extension}"
    if [[ -z "$outfile" ]]; then
        ${printerr} "ERROR: no output file specified."
        ${printusage}
        exit
    fi
    case $infile_ext in
    ${conv_opt_cmds}
    *)
    ${printerr} "ERROR: unhandled input extension ($infile_ext)."
    ${printusage}
    exit
    ;;
    esac
''