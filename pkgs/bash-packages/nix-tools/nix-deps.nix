{ writeShellScriptBin, callPackage, color-prints, nix-tree }:
let
  pkgname = "nix-deps";
  description = "Recurse the dependencies of a Nix package.";
  long-description = ''
    usage: ${pkgname} derivation
       OR e.g.,
           ${pkgname} '<nixpkgs>' -A pkgname
  '';
  argparse = callPackage ../bash-utils/argparse.nix {
    usage_str = ''
      ${long-description}
      ${description}
    '';
    optsWithVarsAndDefaults = [ ];
  };
  printErr = "${color-prints}/bin/echo_red";
in (writeShellScriptBin pkgname ''
  ${argparse}
  if [[ $# -ge 2 ]]; then
      nix-build $@ --no-out-link | xargs -o ${nix-tree}/bin/nix-tree
  elif [[ $# -eq 1 ]]; then
      ${nix-tree}/bin/nix-tree "$1"
  else
      ${printErr} "Must specify either a store path or nix-build rules."
  fi
'') // {
  meta = {
    inherit description;
    longDescription = ''
      ```bash
      ${long-description}
      ```  
    '';
  };
}
