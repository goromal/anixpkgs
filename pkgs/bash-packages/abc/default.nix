# pull in abc, ffmpeg, etc dependencies and replicate clc abc script exactly
{ makeShellScriptBin
, abcm2ps
, abcmidi
, ffmpeg
, inkscape
}:





elif [[ $PP_ACTION == "svg-to-pdf" ]]; then
  echo_yellow "Converting $PP_INFILE -> $PP_OUTFILE..."
  if [[ "$CROP" == "TRUE" ]]; then
    inkscape --file="$PP_INFILE" --export-area-drawing --without-gui --export-pdf="$PP_OUTFILE" > /dev/null 2>&1
  else
    inkscape --file="$PP_INFILE" --without-gui --export-pdf="$PP_OUTFILE" > /dev/null 2>&1
  fi





#!/bin/bash

usage()
{
cat << EOF
usage: abc inputfile outputfile1 [outputfile2...]

Do conversions involving abc music notation files. input/output combinations 
can be
  - midi_song.abc -> midi_song.mid / .ps / .pdf / .svg / .mp3
  - midi_song.mid -> midi_song.abc / .ps / .pdf / .svg / .mp3

The output will always be placed in the directory where the command was invoked.

EOF
}

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" 
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
RESDIR="$DIR/abc_res"
CALLLOC="$PWD"

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  usage
  exit
fi

if [ ! -d "$RESDIR/abc_tools" ]; then
  echo_yellow -n "It appears that abc_tools haven't been installed yet. Remedying... "
  pushd "$RESDIR" > /dev/null 2>&1
  git clone --recurse-submodules https://github.com/goromal/abc_tools.git > /dev/null 2>&1
  cd abc_tools 
  ./setup.sh > /dev/null 2>&1
  echo_yellow "Done."
  popd > /dev/null 2>&1
fi

abc2abc_exe="$RESDIR/abc_tools/abc2abc"
abc2midi_exe="$RESDIR/abc_tools/abc2midi"
abc2ps_exe="$RESDIR/abc_tools/abc2ps"
abcmatch_exe="$RESDIR/abc_tools/abcmatch"
midi2abc_exe="$RESDIR/abc_tools/midi2abc"

INPUTFILE="$1"
if [[ "$INPUTFILE" != /* ]]; then
  INPUTFILE="$CALLLOC/$INPUTFILE"
fi
INPUTFILE_BASE=$(basename -- "$INPUTFILE")
INPUTFILE_EXT="${INPUTFILE_BASE##*.}"
shift

while true; do
  OUTPUTFILE="$1"
  shift
  if [ -z $OUTPUTFILE ]; then
    break
  fi
  echo_yellow "Converting $INPUTFILE to $OUTPUTFILE..."
  OUTPUTFILE_BASE=$(basename -- "$OUTPUTFILE")
  OUTPUTFILE_EXT="${OUTPUTFILE_BASE##*.}"
  OUTPUTFILE_NAME="${OUTPUTFILE_BASE%.*}"

  if [[ "$INPUTFILE_EXT" == "abc" ]]; then
    if [[ "$OUTPUTFILE_EXT" == "mid" ]]; then
      "$abc2midi_exe" "$INPUTFILE" -o "$CALLLOC/$OUTPUTFILE_BASE" > /dev/null 2>&1
    elif [[ "$OUTPUTFILE_EXT" == "mp3" ]]; then
      "$abc2midi_exe" "$INPUTFILE" -o "$RESDIR/$OUTPUTFILE_NAME.mid" > /dev/null 2>&1
      cd "$RESDIR"
      timidity -Ow -o tmp.wav "$OUTPUTFILE_NAME.mid" > /dev/null 2>&1 
      lame tmp.wav "$CALLLOC/$OUTPUTFILE_BASE" > /dev/null 2>&1
      rm tmp.wav
      rm "$OUTPUTFILE_NAME.mid"
    elif [[ "$OUTPUTFILE_EXT" == "ps" ]]; then
      "$abc2ps_exe" "$INPUTFILE" -O "$CALLLOC/$OUTPUTFILE_BASE" > /dev/null 2>&1
    elif [[ "$OUTPUTFILE_EXT" == "pdf" ]]; then
      # convert to individual .svg's first in private location
      "$abc2ps_exe" "$INPUTFILE" -v -O "$RESDIR/$OUTPUTFILE_BASE" > /dev/null 2>&1 # abc2ps ignores the .pdf extension, thankfully
      # convert resultant .svg's into .pdf's and combine into single document
      cd "$RESDIR"
      combinelist=""
      for i in *.svg; do
        [ -f "$i" ] || break
        iname="${i%.*}"
        svgtool -n "$iname.svg" svg-to-pdf "$iname.pdf" > /dev/null 2>&1
        combinelist="$combinelist $iname.pdf"
      done
      pdfunite $combinelist "$CALLLOC/$OUTPUTFILE_BASE"
      rm *.svg
      rm *.pdf
    elif [[ "$OUTPUTFILE_EXT" == "svg" ]]; then
      "$abc2ps_exe" "$INPUTFILE" -g -O "$RESDIR/$OUTPUTFILE_BASE" > /dev/null 2>&1
      OFNAME="${OUTPUTFILE_BASE%.*}"
      mv "$RESDIR/${OFNAME}001.svg" "$CALLLOC/$OUTPUTFILE_BASE"
    else
      echo_red "Unrecognized conversion request."
    fi
  elif [[ "$INPUTFILE_EXT" == "mid" ]]; then
    if [[ "$OUTPUTFILE_EXT" == "abc" ]]; then
      "$midi2abc_exe" "$INPUTFILE" -o "$CALLLOC/$OUTPUTFILE_BASE" > /dev/null 2>&1
    elif [[ "$OUTPUTFILE_EXT" == "mp3" ]]; then
      timidity -Ow -o "$RESDIR/tmp.wav" "$INPUTFILE" > /dev/null 2>&1 
      cd "$RESDIR"
      lame tmp.wav "$CALLLOC/$OUTPUTFILE_BASE" > /dev/null 2>&1
      rm tmp.wav
    elif [[ "$OUTPUTFILE_EXT" == "ps" ]]; then
      cd $(mktemp -d)
      "$midi2abc_exe" "$INPUTFILE" -o "tmp.abc" > /dev/null 2>&1
      abc tmp.abc tmp.ps > /dev/null 2>&1
      mv tmp.ps "$CALLLOC/$OUTPUTFILE_BASE"
      rm tmp.abc
    elif [[ "$OUTPUTFILE_EXT" == "pdf" ]]; then
      cd $(mktemp -d)
      "$midi2abc_exe" "$INPUTFILE" -o "tmp.abc" > /dev/null 2>&1
      abc tmp.abc tmp.pdf > /dev/null 2>&1
      mv tmp.pdf "$CALLLOC/$OUTPUTFILE_BASE"
      rm tmp.abc
    elif [[ "$OUTPUTFILE_EXT" == "svg" ]]; then
      cd $(mktemp -d)
      "$midi2abc_exe" "$INPUTFILE" -o "tmp.abc" > /dev/null 2>&1
      abc tmp.abc tmp.svg > /dev/null 2>&1
      mv tmp.svg "$CALLLOC/$OUTPUTFILE_BASE"
      rm tmp.abc
    else
      echo_red "Unrecognized conversion request."
    fi
  else
    echo_red "Unrecognized conversion request."
  fi
done