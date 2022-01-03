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
    ''; # ${argparse}
in writeShellScriptBin name ''
    ${argparse}
    infile="$1"
    if [[ -z "$infile" ]]; then
        ${printerr} "ERROR: no input file specified."
        ${printusage}
        exit
    fi
    infile_ext=${strings.getExtension "infile"}
    echo_green "INFILE_EXT=$infile_ext"
    outfile=${strings.replaceExtension "2" extension}
    echo_green "OUTFILE=$outfile"
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