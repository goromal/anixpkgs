{
  writeArgparseScriptBin,
  callPackage,
  color-prints,
  strings,
  redirects,
  ffmpeg,
  rubberband,
  abcmidi,
  timidity,
  jq,
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
        .abc

    Options:
        --transpose [+- # HALF STEPS]
            Powered by https://github.com/breakfastquay/rubberband.
        --normalize [TARGET LUFS, e.g. -14.0]
            Match integrated loudness to the target via a two-pass ffmpeg
            loudnorm, with a -1.0 dBTP true-peak ceiling. Gain is applied
            linearly when the peaks allow it; otherwise loudnorm limits
            dynamically and a warning is printed. Applied after --transpose.
  '';
  optsWithVarsAndDefaults = [
    {
      var = "transpose";
      isBool = false;
      default = "NULL";
      flags = "--transpose";
    }
    {
      var = "normalize";
      isBool = false;
      default = "NULL";
      flags = "--normalize";
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
  # Two-pass loudnorm: measure, then apply with the measurements so the gain can
  # be linear. loudnorm resamples to 192 kHz internally, so the source sample
  # rate is restored on output. Cover art and tags are carried over.
  apply_normalize = tmpdir_var: infile_var: outfile_varname: ''
    if ! [[ "$normalize" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
        >&2 ${color-prints}/bin/echo_red "ERROR: --normalize expects a LUFS number (got $normalize)."
        exit 1
    fi
    normin=${infile_var}
    lnorm="I=$normalize:TP=-1.0:LRA=50"
    ${ffmpeg}/bin/ffmpeg -hide_banner -nostats -i "$normin" -af "loudnorm=$lnorm:print_format=json" -f null - 2> "${tmpdir_var}/pass1.log"
    pass1=$(sed -n '/^{/,/^}/p' "${tmpdir_var}/pass1.log")
    m() { echo "$pass1" | ${jq}/bin/jq -r ".$1"; }
    measured="measured_I=$(m input_i):measured_TP=$(m input_tp):measured_LRA=$(m input_lra):measured_thresh=$(m input_thresh):offset=$(m target_offset)"
    srate=$(${ffmpeg}/bin/ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of default=nw=1:nk=1 "$normin")
    ${outfile_varname}="${tmpdir_var}/postnorm.mp3"
    ${ffmpeg}/bin/ffmpeg -hide_banner -nostats -y -i "$normin" -map 0:a:0 -map "0:v?" -c:v copy -map_metadata 0 \
        -af "loudnorm=$lnorm:$measured:linear=true:print_format=json" -ar "$srate" \
        -c:a libmp3lame -q:a 0 -id3v2_version 3 "''${${outfile_varname}}" 2> "${tmpdir_var}/pass2.log" || {
        >&2 ${color-prints}/bin/echo_red "ERROR: loudnorm pass failed:"
        >&2 tail -5 "${tmpdir_var}/pass2.log"
        exit 1
    }
    normtype=$(sed -n '/^{/,/^}/p' "${tmpdir_var}/pass2.log" | ${jq}/bin/jq -r .normalization_type)
    echo "$(m input_i) LUFS -> $normalize LUFS ($normtype)"
    if [[ "$normtype" != "linear" ]]; then
        ${color-prints}/bin/echo_yellow "WARNING: peaks exceed the ceiling at this gain; loudnorm compressed the dynamics."
    fi
  '';
  convOptCmds = [
    {
      extension = "mp3|MP3";
      commands = ''
        tmpdir=$(mktemp -d)
        if [[ "$transpose" != "NULL" ]]; then
            ${apply_transpose "$tmpdir" "$infile" "_stp1"}
        else
            _stp1="$infile"
        fi
        if [[ "$normalize" != "NULL" ]]; then
            ${apply_normalize "$tmpdir" "$_stp1" "_stp1"}
        fi
        mv "$_stp1" "$outfile"
        rm -rf $tmpdir
      '';
    }
    {
      extension = "mp4|MP4";
      commands = ''
        tmpdir=$(mktemp -d)
        _stp1="$tmpdir/_mp42mp3.mp3"
        ${ffmpeg}/bin/ffmpeg -i "$infile" -q:a 0 -map a "$_stp1" ${redirects.suppress_all}
        if [[ "$transpose" != "NULL" ]]; then
            ${apply_transpose "$tmpdir" "$_stp1" "_stp2"}
        else
            _stp2="$_stp1"
        fi
        if [[ "$normalize" != "NULL" ]]; then
            ${apply_normalize "$tmpdir" "$_stp2" "_stp2"}
        fi
        mv "$_stp2" "$outfile"
        rm -rf $tmpdir
      '';
    }
    {
      extension = "wav|WAV";
      commands = ''
        tmpdir=$(mktemp -d)
        _stp1="$tmpdir/_wav2mp3.mp3"
        ${ffmpeg}/bin/ffmpeg -i "$infile" -q:a 0 "$_stp1" ${redirects.suppress_all}
        if [[ "$transpose" != "NULL" ]]; then
            ${apply_transpose "$tmpdir" "$_stp1" "_stp2"}
        else
            _stp2="$_stp1"
        fi
        if [[ "$normalize" != "NULL" ]]; then
            ${apply_normalize "$tmpdir" "$_stp2" "_stp2"}
        fi
        mv "$_stp2" "$outfile"
        rm -rf $tmpdir
      '';
    }
    {
      extension = "abc|ABC";
      commands = ''
        tmpdir=$(mktemp -d)
        _stp1="$tmpdir/_abc2midi.midi"
        ${abcmidi}/bin/abc2midi "$infile" -o "$_stp1" ${redirects.suppress_all}
        _stp2="$tmpdir/_midi2mp3.mp3"
        ${timidity}/bin/timidity "$_stp1" -Ow -o - | ${ffmpeg}/bin/ffmpeg -i - -acodec libmp3lame -ab 64k "$_stp2" ${redirects.suppress_all}
        if [[ "$transpose" != "NULL" ]]; then
            ${apply_transpose "$tmpdir" "$_stp2" "_stp3"}
        else
            _stp3="$_stp2"
        fi
        if [[ "$normalize" != "NULL" ]]; then
            ${apply_normalize "$tmpdir" "$_stp3" "_stp3"}
        fi
        mv "$_stp3" "$outfile"
        rm -rf $tmpdir
      '';
    }
  ];
in
callPackage ./mkConverter.nix {
  inherit writeArgparseScriptBin color-prints strings;
  inherit
    name
    extension
    usage_str
    optsWithVarsAndDefaults
    convOptCmds
    ;
  description = "Generate (or modify) an MP3 file from similar formats.";
}
