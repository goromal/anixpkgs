{ writeArgparseScriptBin, color-prints }:
let
  pkgname = "pkgshell";
  usage_str = ''
    usage: ${pkgname} [options] pkgs attr [--run CMD]

    Make a nix shell with package [attr] from [pkgs] (e.g., '<nixpkgs>').
    Optionally run a one-off command with --run CMD.

    Special values for [pkgs]:
      anixpkgs      Fetch the latest anixpkgs from GitHub

    Options:
    -v|--verbose    Print verbose output.
  '';
  printErr = "${color-prints}/bin/echo_red";
  shellFile = ../bash-utils/customShell.nix;
in
(writeArgparseScriptBin pkgname usage_str
  [
    {
      var = "verbose";
      isBool = true;
      default = "0";
      flags = "-v|--verbose";
    }
    {
      var = "runcmd";
      isBool = false;
      default = "";
      flags = "--run";
    }
  ]
  ''
    set -e
    pkgs="$1"
    attr="$2"
    if [[ -z "$pkgs" ]]; then
        ${printErr} "pkgs not provided"
        exit 1
    fi
    if [[ -z "$attr" ]]; then
        ${printErr} "attr not provided"
        exit 1
    fi
    flags=""
    if [[ "$verbose" == "1" ]]; then
        flags="-v"
    fi
    if [[ "$pkgs" == "anixpkgs" ]]; then
      pkgpath=$(nix-build -E 'with (import (fetchTarball "https://github.com/goromal/anixpkgs/archive/refs/heads/master.tar.gz") {}); '$attr --no-out-link)
    else
      pkgpath=$(nix-build "$pkgs" -A "$attr" --no-out-link)
    fi
    if [[ -z "$runcmd" ]]; then
      nix-shell $flags ${shellFile} \
        --arg pkgList "[ $pkgpath ]" \
        --argstr shellName "pkgshell=$attr" \
        --arg colorCode 35
    else
      nix-shell $flags ${shellFile} \
        --arg pkgList "[ $pkgpath ]" \
        --argstr shellName "pkgshell=$attr" \
        --arg colorCode 35 \
        --command "$runcmd"
    fi
  ''
)
// {
  meta = {
    description = "Flexible Nix shell.";
    longDescription = "";
    autoGenUsageCmd = "--help";
  };
}
