{ writeShellScriptBin, callPackage, color-prints }:
let
  pkgname = "gitcop";
  argparse = callPackage ../bash-utils/argparse.nix {
    usage_str = ''
      usage: ${pkgname} [-f] branch_name

      "Git CheckOut and Pull." Assumes remote is named `origin`. Optional -f flag fetches first.
    '';
    optsWithVarsAndDefaults = [{
      var = "fetch";
      isBool = true;
      default = "0";
      flags = "-f";
    }];
  };
  printError = "${color-prints}/bin/echo_red";
  printYellow = "${color-prints}/bin/echo_yellow";
in (writeShellScriptBin pkgname ''
  ${argparse}
  if [[ -z "$1" ]]; then
      ${printError} "No branch name provided."
      exit 1
  fi
  pause_secs=1
  if [[ "$fetch" == "1" ]]; then
      ${printYellow} "git fetch origin $1 && git checkout $1 && git pull origin $1"
      git fetch origin "$1" && sleep $pause_secs && git checkout "$1" && sleep $pause_secs && git pull origin "$1"
  else
      ${printYellow} "git checkout $1 && git pull origin $1"
      git checkout "$1" && sleep $pause_secs && git pull origin "$1"
  fi
'') // {
  meta = {
    description = "Git CheckOut and Pull";
    longDescription = ''
      ```
      usage: ${pkgname} [-f] branch_name

      Assumes remote is named `origin`. Optional -f flag fetches first.
      ```
    '';
  };
}
