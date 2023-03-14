{ writeShellScriptBin
, callPackage
, color-prints
, wiki-tools
}:
let
    pkgname = "providence";
    argparse = callPackage ../bash-utils/argparse.nix {
        usage_str = ''
        usage: ${pkgname} domain

        Pick randomly from a specified domain:
        - patriarchal
        - passage
        '';
        optsWithVarsAndDefaults = [];
    };
    printGrn = "${color-prints}/bin/echo_green";
    printErr = "${color-prints}/bin/echo_red";
    wikitools = "${wiki-tools}/bin/wiki-tools";
in writeShellScriptBin pkgname ''
    ${argparse}
    if [[ -z "$1" ]]; then
        ${printErr} "No domain chosen."
        exit 1
    fi
    domain="$1"
    if [[ "$domain" == "patriarchal" ]]; then
        readarray -t sentences <<< $(${wikitools} get --page-id andrews-blessing | tr '\n' ' ' | sed -e :1 -e 's/\([.?!]\)[[:blank:]]\{1,\}\([^[:blank:]]\)/\1\n\2/;t1')
        RANDOM=$$$(date +%s)
        ${printGrn} ''${sentences[ $RANDOM % ''${#sentences[@]} ]}
    elif [[ "$domain" == "passage" ]]; then
        ${printErr} "Not implemented yet! Sorry."
        exit 1
    else
        ${printErr} "Unrecognized domain: $domain."
        exit 1
    fi
''
