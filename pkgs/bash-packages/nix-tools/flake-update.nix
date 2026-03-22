{ writeArgparseScriptBin, color-prints }:
let
  pkgname = "flake-update";
  description = "Automatically update the flake lock of every changed ref (according to Git diff).";
  long-description = ''
    usage: ${pkgname} [path/to/flake.nix]
  '';
  usage_str = ''
    ${long-description}
    ${description}
  '';
  printErr = "${color-prints}/bin/echo_red";
  printYlw = "${color-prints}/bin/echo_yellow";
  printGrn = "${color-prints}/bin/echo_green";
in
(writeArgparseScriptBin pkgname usage_str [ ] ''
  flakefile="flake.nix"
  if [[ ! -z "$1" ]]; then
      flakefile="$1"
  fi
  if [[ ! -f "$flakefile" ]]; then
      ${printErr} "Specified flake file $flakefile does not exist."
      exit 1
  fi
  flakedir="$(dirname $(realpath $flakefile))"
  cd $flakedir
  readarray -t sources < <(git diff flake.nix | grep -oP '^\+\s+\K\S+(?=\.url)')
  for source in "''${sources[@]}"; do
      ${printYlw} "Detected changed source $source"
      nix flake update "$source" || nix flake lock --update-input "$source"
  done
  ${printGrn} Done.
'')
// {
  meta = {
    inherit description;
    longDescription = "";
    autoGenUsageCmd = "--help";
  };
}
