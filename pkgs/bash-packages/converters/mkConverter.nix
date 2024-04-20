{ writeArgparseScriptBin, color-prints, strings, name, extension, usage_str
, optsWithVarsAndDefaults, convOptCmds, description ? "", longDescription ? null
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
  printusage = ''
        cat << EOF
    ${usage_str}
    EOF
  '';
in (writeArgparseScriptBin name usage_str optsWithVarsAndDefaults ''
  infile="$1"
  if [[ -z "$infile" ]]; then
      ${printerr} "ERROR: no input file specified."
      ${printusage}
      exit 1
  fi
  infile_ext=`${strings.getExtension} "$infile"`
  if [[ -z "$2" ]]; then
      ${printerr} "ERROR: no output file specified."
      ${printusage}
      exit 1
  fi
  outfile=`${strings.replaceExtension} "$2" ${extension}`
  case $infile_ext in
  ${conv_opt_cmds}
  *)
  ${printerr} "ERROR: unhandled input extension ($infile_ext)."
  ${printusage}
  exit 1
  ;;
  esac
'') // {
  meta = {
    inherit description;
    longDescription = (if longDescription != null then
      longDescription
    else ''
      ```
      ${usage_str}
      ```
    '');
  };
}
