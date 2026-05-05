{ usage_str, optsWithVarsAndDefaults }:
let
  def_assign_list = map (x: "${x.var}=${x.default}") optsWithVarsAndDefaults;
  def_assigns = builtins.concatStringsSep "\n" def_assign_list;
  arg_opt_assign_list = map (x: ''
    ${x.flags})
    ${if x.isBool then "" else "shift"}
    ${x.var}=${if x.isBool then "1" else "$1"}
    shift
    ;;
  '') optsWithVarsAndDefaults;
  arg_opt_assigns = builtins.concatStringsSep "\n" arg_opt_assign_list;
in
''
  ${def_assigns}
  POSITIONAL=()
  while [[ $# -gt 0 ]]
  do
  key="$1"
  case $key in
      -h|--help)
      cat << EOF
  ${usage_str}
  EOF
      exit
      ;;
      ${arg_opt_assigns}
      *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
  done
  set -- "''${POSITIONAL[@]}"
''
