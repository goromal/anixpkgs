{ writeShellScriptBin, callPackage, color-prints }:
let
  pkgname = "pkgshell";
  argparse = callPackage ../bash-utils/argparse.nix {
    usage_str = ''
      usage: ${pkgname} [options] pkgs attr

      Make a nix shell with package [attr] from [pkgs] (e.g., '<nixpkgs>').

      Options:
      -v|--verbose    Print verbose output.
    '';
    optsWithVarsAndDefaults = [{
      var = "verbose";
      isBool = true;
      default = "0";
      flags = "-v|--verbose";
    }];
  };
  printErr = "${color-prints}/bin/echo_red";
  shellFile = ../bash-utils/customShell.nix;
in (writeShellScriptBin pkgname ''
  ${argparse}
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
  pkgpath=$(nix-build "$pkgs" -A "$attr" --no-out-link)
  nix-shell $flags ${shellFile} \
    --arg pkgList "[ $pkgpath ]" \
    --argstr shellName "pkgshell=$attr" \
    --arg colorCode 35
'') // {
  meta = {
    description = "Flexible Nix shell.";
    longDescription = ''
      ```
      usage: pkgshell [options] pkgs attr

      Make a nix shell with package [attr] from [pkgs] (e.g., '<nixpkgs>').

      Options:
      -v|--verbose    Print verbose output.
      ```
    '';
  };
}
