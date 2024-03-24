{ writeArgparseScriptBin, color-prints, redirects, git-cc }:
let
  pkgname = "rust-helper";
  anix-version = (builtins.readFile ../../../ANIX_VERSION);
  usage_str = ''
    usage: ${pkgname} [options]

    Options:
    --make-nix    Dump template shell.nix file
  '';
  printErr = "${color-prints}/bin/echo_red";
  printGrn = "${color-prints}/bin/echo_green";
  shellFile = ./res/_shell.nix;
  makenixRule = ''
    if [[ "$makenix" == "1" ]]; then
        ${printGrn} "Generating template shell.nix file..."
        cat ${shellFile} > shell.nix
        sed -i 's|REPLACEME|${anix-version}|g' shell.nix
    fi
  '';
in (writeArgparseScriptBin pkgname usage_str [{
  var = "makenix";
  isBool = true;
  default = "0";
  flags = "--make-nix";
}] ''
  set -e
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
