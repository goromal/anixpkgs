{ writeShellScriptBin, callPackage, color-prints, redirects, git-cc }:
let
  pkgname = "rust-helper";
  usage_str = ''
    usage: ${pkgname} [options]

    Options:
    --make-nix    Dump template shell.nix file
  '';
  argparse = callPackage ../bash-utils/argparse.nix {
    inherit usage_str;
    optsWithVarsAndDefaults = [
      {
        var = "makenix";
        isBool = true;
        default = "0";
        flags = "--make-nix";
      }
    ];
  };
  printErr = "${color-prints}/bin/echo_red";
  printGrn = "${color-prints}/bin/echo_green";
  shellFile = ./res/_shell.nix;
  makenixRule = ''
    if [[ "$makenix" == "1" ]]; then
        ${printGrn} "Generating template shell.nix file..."
        cat ${shellFile} > shell.nix
    fi
  '';
in (writeShellScriptBin pkgname ''
  set -e
  ${argparse}
  tmpdir=$(mktemp -d)
  ${makenixRule}
  rm -rf "$tmpdir"
'') // {
  meta = {
    description = "Convenience tools for setting up Rust projects.";
    longDescription = ''
      ***Under construction.***

      ```bash
      ${usage_str}
      ```
    '';
  };
}
