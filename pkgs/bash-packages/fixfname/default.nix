{ writeShellScriptBin
, callPackage
, strings
}:
let
    pkgname = "fixfname";
    argparse = callPackage ../bash-utils/argparse.nix {
        usage_str = ''
        usage: ${pkgname} FILE

        Replace spaces and remove [], () characters from a filename (in place).
        '';
        optsWithVarsAndDefaults = [];
    };
in (writeShellScriptBin pkgname ''
    ${argparse}
    fname="$1"
    pt1=$(${strings.dashSpaces} "$fname")
    pt2=$(${strings.removeListNotation} "$pt1")
    newfname="$pt2"
    echo "$fname -> $newfname"
    mv "$fname" "$newfname"
'') // {
    meta = {
        description = "Unix-ify filenames.";
        longDescription = ''
        ```
        usage: fixfname FILE

        Replace spaces and remove [], () characters from a filename (in place).
        ```
        '';
    };
}
