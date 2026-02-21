{
  writeArgparseScriptBin,
  color-prints,
  redirects,
  abcmidi,
  timidity,
}:
let
  pkgname = "playabc";
  printErr = "${color-prints}/bin/echo_red";
  printCyn = "${color-prints}/bin/echo_cyan";
in
(writeArgparseScriptBin pkgname
  ''
    usage: ${pkgname} FILE.abc

    Play an ABC music file through the computer speakers.

    This tool converts the ABC file to MIDI and plays it using timidity.
  ''
  [ ]
  ''
    if [[ -z "$1" ]]; then
      ${printErr} "No ABC file specified."
      exit 1
    fi

    ABCFILE="$1"

    if [[ ! -f "$ABCFILE" ]]; then
      ${printErr} "File not found: $ABCFILE"
      exit 1
    fi

    # Check if file has .abc extension
    if [[ "$ABCFILE" != *.abc && "$ABCFILE" != *.ABC ]]; then
      ${printErr} "File does not have .abc extension: $ABCFILE"
      exit 1
    fi

    ${printCyn} "Converting ABC to MIDI..."
    TMPDIR=$(mktemp -d)
    MIDIFILE="$TMPDIR/song.midi"

    ${abcmidi}/bin/abc2midi "$ABCFILE" -o "$MIDIFILE" ${redirects.suppress_all}

    if [[ $? -ne 0 ]]; then
      ${printErr} "Failed to convert ABC to MIDI."
      rm -rf "$TMPDIR"
      exit 1
    fi

    ${printCyn} "Playing..."
    ${timidity}/bin/timidity "$MIDIFILE" ${redirects.suppress_all}

    # Clean up
    rm -rf "$TMPDIR"
  ''
)
// {
  meta = {
    description = "Play ABC music files through the computer speakers.";
    longDescription = "Converts ABC notation files to MIDI and plays them using timidity.";
    autoGenUsageCmd = "--help";
  };
}
