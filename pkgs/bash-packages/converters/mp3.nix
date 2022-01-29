{ writeShellScriptBin
, callPackage
, color-prints
, strings
, redirects
}: # TODO package is in a test state
let
    name = "mp3";
    extension = "mp3";
    usage_str = ''
    usage: mp3 inputfile outputfile

    Create an mp3 file.

    Inputs:
        .TODO

    Options:
        --one   (T/F)
        --two   TWO
        --three (T/F)
    '';
    optsWithVarsAndDefaults = [
        {
            var = "one";
            isBool = true;
            default = "0";
            flags = "--one";
        }
        {
            var = "two";
            isBool = false;
            default = "UNSET";
            flags = "--two";
        }
        {
            var = "three";
            isBool = true;
            default = "0";
            flags = "--three";
        }
    ];
    convOptCmds = [
        { extension = "pdf|PDF"; commands = ''
        echo_green "inputfile: $infile"
        echo_green "outputfile: $outfile"
        echo_yellow "one: $one"
        echo_yellow "two: $two"
        echo_yellow "three: $three"
        ''; }
    ];
in callPackage ./mkConverter.nix {
    inherit writeShellScriptBin callPackage color-prints strings;
    inherit name extension usage_str optsWithVarsAndDefaults convOptCmds;
}