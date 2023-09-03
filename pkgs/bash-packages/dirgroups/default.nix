{ writeShellScriptBin, callPackage, color-prints }:
let
  pkgname = "dirgroups";
  argparse = callPackage ../bash-utils/argparse.nix {
    usage_str = ''
      usage: ${pkgname} num_groups dir
                      OR
             ${pkgname} --of group_size dir

      Split a large directory of files into smaller directories with evenly distributed files (not counting remainders). 
    '';
    optsWithVarsAndDefaults = [{
      var = "group_size";
      isBool = false;
      default = "";
      flags = "--of";
    }];
  };
  printErr = "${color-prints}/bin/echo_red";
  printGrn = "${color-prints}/bin/echo_green";
in (writeShellScriptBin pkgname ''
  set -e
  ${argparse}
  if [[ -z "$group_size" ]]; then
      if [[ -z "$2" ]]; then
          ${printErr} "No dir specified."
          exit 1
      else
          dirtosplit="$2"
      fi
      if [[ -z "$1" ]]; then
          ${printErr} "No num_groups specified."
          exit 1
      else
          nf=$(ls -1 "$dirtosplit" | wc -l)
          ng=$1
          n=$(((nf+ng-1)/$ng))
      fi
  else
      n=$group_size
      if [[ -z "$1" ]]; then
          ${printErr} "No dir specified."
          exit 1
      else
          dirtosplit="$1"
      fi
  fi
  i=0
  d=0
  for f in $dirtosplit/*; do
      if [[ $((i % n)) == 0 ]]; then
          d=$((d+1))
          mkdir $dirtosplit/_split_$d
      fi
      mv $f $dirtosplit/_split_$d
      i=$((i+1))
  done
  ${printGrn} "Split $dirtosplit into $d groups of <= $n."
'') // {
  meta = {
    description = "Split directories into smaller ones.";
    longDescription = ''
      ```
      usage: dirgroups num_groups dir
                      OR
             dirgroups --of group_size dir

      Split a large directory of files into smaller directories with evenly distributed files (not counting remainders). 
      ```
    '';
  };
}
