{ writeShellScriptBin
, callPackage
, color-prints
, strings
, redirects
, ffmpeg
}:
let
    name = "mp4";
    extension = "mp4";
    usage_str = ''
    usage: mp4 inputfile outputfile

    Create a mp4 file.

    Inputs:
        .mp4
        .gif
        .mpeg
        .mkv
        .mov
        .avi

    Options:
        --TODO
    '';
    optsWithVarsAndDefaults = [
        
    ];
    convOptCmds = [ # TODO
        { extension = "*"; commands = ''
        ${ffmpeg}/bin/ffmpeg -i $infile -vcodec libx264 $outfile ${redirects.suppress_all}
        ''; }
    ];
in callPackage ./mkConverter.nix {
    inherit writeShellScriptBin callPackage color-prints strings;
    inherit name extension usage_str optsWithVarsAndDefaults convOptCmds;
}