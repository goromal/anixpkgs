{ writeArgparseScriptBin, color-prints }:
let
  pkgname = "pkgshell";
  usage_str = ''
    usage: ${pkgname} [options] pkgs attr

    Make a nix shell with package [attr] from [pkgs] (e.g., '<nixpkgs>').

    Options:
    -v|--verbose    Print verbose output.
  '';
  printErr = "${color-prints}/bin/echo_red";
  shellFile = ../bash-utils/customShell.nix;
in (writeArgparseScriptBin pkgname usage_str [{
  var = "verbose";
  isBool = true;
  default = "0";
  flags = "-v|--verbose";
}] ''
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
      ${usage_str}
      ```
    '';
  };
}
