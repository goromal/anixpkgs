{
  writeArgparseScriptBin,
  writeShellScript,
  color-prints,
  redirects,
  git-cc,
  anixpkgs-version,
  cargo,
  rustc,
  rustfmt,
  python3,
}:
let
  pkgname = "rust-helper";
  usage_str = ''
    usage: ${pkgname} [options]

    Options:
        dev                         Drop directly into a Rust development shell

        nix                         Dump template shell.nix file
        vscode DEFAULT[:OTHER:ENV]  Generate VSCode settings file for rust-analyzer
                                    (Run inside a Nix dev environment)
  '';
  printErr = "${color-prints}/bin/echo_red";
  printWrn = "${color-prints}/bin/echo_yellow";
  printGrn = "${color-prints}/bin/echo_green";
  directShellFile = ../bash-utils/customShell.nix;
  shellFile = ./res/_shell.nix;
  settingsAddScript = ./addsettings.py;
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
  makevscodeScript = writeShellScript "makevscode" ''
    makevscodeargs="$1"
    export SETTINGS_JSON="$PWD/.vscode/settings.json"
    ${printGrn} "Generating rust-analyzer-compatible config for code completion in VSCode ($SETTINGS_JSON)..."
    mkdir -p "$PWD/.vscode"
    IFS=':' read -ra vararray <<< "$makevscodeargs"
    for envvar in "''${vararray[@]}"; do
        if [[ "$envvar" == "DEFAULT" ]]; then
            ${python3}/bin/python ${settingsAddScript} "$SETTINGS_JSON" "RUSTC" "$(which rustc)"
            ${python3}/bin/python ${settingsAddScript} "$SETTINGS_JSON" "CARGO" "$(which cargo)"
            ${python3}/bin/python ${settingsAddScript} "$SETTINGS_JSON" "RUSTFMT" "$(which rustfmt)"
        else
            ${python3}/bin/python ${settingsAddScript} "$SETTINGS_JSON" "$envvar" "''${!envvar}"
        fi
    done
  '';
  makevscodeRule = ''
    if [[ ! -z "$makevscode" ]]; then
        if [[ -f shell.nix ]]; then
            nix-shell --command 'bash ${makevscodeScript} '"$makevscode"
        elif [[ -f flake.nix ]]; then
            nix develop --command 'bash ${makevscodeScript} '"$makevscode"
        else
            ${printWrn} "WARNING: could not find a nix development environment to run."
            bash ${makevscodeScript} "$makevscode"
        fi
    fi
  '';
in
(writeArgparseScriptBin pkgname usage_str
  [
    {
      var = "makenix";
      isBool = true;
      default = "0";
      flags = "nix";
    }
    {
      var = "dev";
      isBool = true;
      default = "0";
      flags = "dev";
    }
    {
      var = "makevscode";
      isBool = false;
      default = "";
      flags = "vscode";
    }
  ]
  ''
    set -e
    tmpdir=$(mktemp -d)
    ${makenixRule}
    ${makevscodeRule}
    rm -rf "$tmpdir"
    ${makedevRule}
  ''
)
// {
  meta = {
    description = "Convenience tools for setting up Rust projects.";
    longDescription = "";
    autoGenUsageCmd = "--help";
  };
}
