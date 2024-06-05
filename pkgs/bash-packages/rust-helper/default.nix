{ writeArgparseScriptBin, color-prints, redirects, git-cc, anixpkgs-version
, cargo, rustc, rustfmt }:
let
  pkgname = "rust-helper";
  usage_str = ''
    usage: ${pkgname} [options]

    Options:
    --dev         Drop directly into a Rust development shell
    --make-nix    Dump template shell.nix file
  '';
  printErr = "${color-prints}/bin/echo_red";
  printGrn = "${color-prints}/bin/echo_green";
  directShellFile = ../bash-utils/customShell.nix;
  shellFile = ./res/_shell.nix;
  # last possible rule executed; can't make use of tmpdir
  makedevRule = ''
    if [[ "$dev" == "1" ]]; then
        ${printGrn} "Entering a Rust development shell from anixpkgs v${anixpkgs-version}..."
        nix-shell ${directShellFile} \
          --argstr shellName "Rust" \
          --arg pkgList "[ ${cargo} ${rustc} ${rustfmt} ]" \
          --arg colorCode 31
    fi
  '';
  makenixRule = ''
    if [[ "$makenix" == "1" ]]; then
        ${printGrn} "Generating template shell.nix file..."
        cat ${shellFile} > shell.nix
        sed -i 's|REPLACEME|${anixpkgs-version}|g' shell.nix
    fi
  '';
in (writeArgparseScriptBin pkgname usage_str [
  {
    var = "makenix";
    isBool = true;
    default = "0";
    flags = "--make-nix";
  }
  {
    var = "dev";
    isBool = true;
    default = "0";
    flags = "--dev";
  }
] ''
  set -e
  tmpdir=$(mktemp -d)
  ${makenixRule}
  rm -rf "$tmpdir"
  ${makedevRule}
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
