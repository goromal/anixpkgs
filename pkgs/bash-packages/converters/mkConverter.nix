{
  lib,
  writeArgparseScriptBin,
  color-prints,
  strings,
  name,
  extension,
  usage_str,
  optsWithVarsAndDefaults,
  convOptCmds,
  description ? "",
  longDescription ? "",
  autoGenUsageCmd ? "--help",
}:
let
  conv_opt_list = map (x: ''
    ${x.extension})
    echo "$infile -> $outfile ..."
    ${x.commands}
    ;;
  '') convOptCmds;
  conv_opt_cmds = builtins.concatStringsSep "\n" conv_opt_list;
  printerr = ">&2 ${color-prints}/bin/echo_red";
  printwarn = "${color-prints}/bin/echo_yellow";
  printusage = ''
        cat << EOF
    ${usage_str}
    EOF
  '';

  # Input extensions that `vacuum` can discover on disk. The `random`
  # pseudo-extension is synthesized from a filename spec rather than read off a
  # real file, so it is excluded.
  isRandomToken =
    e:
    builtins.elem (lib.toLower e) [
      "random"
      "rand"
    ];
  inputExtTokens = lib.concatMap (x: lib.splitString "|" x.extension) convOptCmds;
  vacuumExts = lib.unique (map lib.toLower (lib.filter (e: !isRandomToken e) inputExtTokens));
  inameArgs = lib.concatStringsSep " -o " (map (e: ''-iname "*.${e}"'') vacuumExts);
in
(writeArgparseScriptBin name usage_str optsWithVarsAndDefaults ''
  convert_one() {
      infile="$1"
      outfile="$2"
      infile_ext=`${strings.getExtension} "$infile"`
      case $infile_ext in
      ${conv_opt_cmds}
      *)
      ${printerr} "ERROR: unhandled input extension ($infile_ext)."
      ${printusage}
      exit 1
      ;;
      esac
  }

  if [[ "$1" == "vacuum" ]]; then
      indir="$2"
      if [[ -z "$indir" ]]; then
          ${printerr} "ERROR: no input directory specified."
          ${printusage}
          exit 1
      fi
      if [[ ! -d "$indir" ]]; then
          ${printerr} "ERROR: not a directory ($indir)."
          exit 1
      fi
      found=0
      while IFS= read -r -d "" f; do
          found=1
          outfile=`${strings.replaceExtension} "$f" ${extension}`
          convert_one "$f" "$outfile"
      done < <(find "$indir" -maxdepth 1 -type f \( ${inameArgs} \) -print0 | sort -z)
      if [[ "$found" == "0" ]]; then
          ${printwarn} "No files with supported extensions found in $indir."
      fi
      exit 0
  fi

  infile="$1"
  if [[ -z "$infile" ]]; then
      ${printerr} "ERROR: no input file specified."
      ${printusage}
      exit 1
  fi
  if [[ -z "$2" ]]; then
      ${printerr} "ERROR: no output file specified."
      ${printusage}
      exit 1
  fi
  outfile=`${strings.replaceExtension} "$2" ${extension}`
  convert_one "$infile" "$outfile"
'')
// {
  meta = { inherit description longDescription autoGenUsageCmd; };
}
