{ writeShellScriptBin
, callPackage
, color-prints
, strings
, redirects
, ffmpeg
, rubberband
}:
let
    name = "mp3";
    extension = "mp3";
    usage_str = ''
    usage: mp3 inputfile outputfile

    Create a mp3 file.

    Inputs:
        .mp3
        .mp4
        .wav
        .midi

    Options:
        --transpose [+- # HALF STEPS]
        --TODO
    '';
    optsWithVarsAndDefaults = [
        {
            var = "transpose";
            isBool = false;
            default = "NULL";
            flags = "--transpose";
        }
    ];
    apply_transpose = tmpdir_var: infile_var: outfile_varname: ''
    ext=`${strings.getExtension} ${infile_var}`
    if [[ "$ext" != "wav" && "$ext" != "WAV" ]]; then
        pretranswav="${tmpdir_var}/pretranswav.wav"
        ${ffmpeg}/bin/ffmpeg -i ${infile_var} "$pretranswav" ${redirects.suppress_all}
    else
        pretranswav="${infile_var}"
    fi
    ${rubberband}/bin/rubberband -p $transpose "$pretranswav" "${tmpdir_var}/transwav.wav" ${redirects.suppress_all} 
    ${outfile_varname}="${tmpdir_var}/posttrans.mp3"
    ${ffmpeg}/bin/ffmpeg -i "${tmpdir_var}/transwav.wav" "''${${outfile_varname}}" ${redirects.suppress_all}
    '';
    convOptCmds = [
        { extension = "mp3|MP3"; commands = ''
        tmpdir=$(mktemp -d)
        if [[ "$transpose" != "NULL" ]]; then
            ${apply_transpose "$tmpdir" "$infile" "_stp1"}
        else
            _stp1="$infile"
        fi
        mv "$_stp1" "$outfile"
        rm -rf $tmpdir
        ''; }
        { extension = "mp4|MP4"; commands = ''
        tmpdir=$(mktemp -d)
        _stp1="$tmpdir/_mp42mp3.mp3"
        ${ffmpeg}/bin/ffmpeg -i "$infile" -q:a 0 -map a "$_stp1" ${redirects.suppress_all}
        if [[ "$transpose" != "NULL" ]]; then
            ${apply_transpose "$tmpdir" "$_stp1" "_stp2"}
        else
            _stp2="$_stp1"
        fi
        mv "$_stp2" "$outfile"
        rm -rf $tmpdir
        ''; }
    ];
in callPackage ./mkConverter.nix {
    inherit writeShellScriptBin callPackage color-prints strings;
    inherit name extension usage_str optsWithVarsAndDefaults convOptCmds;
}