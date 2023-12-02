{ writeShellScriptBin, callPackage, color-prints }:
let
  pkgname = "fix-perms";
  argparse = callPackage ../bash-utils/argparse.nix {
    usage_str = ''
      usage: ${pkgname} dir

      Recursively claim ownership of all files and folders in dir. Attempts to deduce special cases such as ~/.ssh/*.
    '';
    optsWithVarsAndDefaults = [ ];
  };
  printErr = "${color-prints}/bin/echo_red";
  printYlw = "${color-prints}/bin/echo_yellow";
  printGrn = "${color-prints}/bin/echo_green";
in (writeShellScriptBin pkgname ''
  ${argparse}
  if [[ -z "$1" ]]; then
      ${printErr} "No dir provided."
      exit 1
  fi
  if [[ "$(readlink -f $1)" == *.ssh* ]]; then
      ${printYlw} "Deducing SSH perms rules."
      # TODO
  else
      ${printYlw} "Applying standard file + dir perms."
      find "$1" -type d -exec chmod 755 {} \;
      find "$1" -type f -exec chmod 644 {} \;
  fi
  ${printGrn} "Done!"
'') // {
  meta = {
    description =
      "Recursively claim ownership of all files and folders in dir.";
    longDescription = ''
      ```
      usage: fix-perms dir
      ```

      Attempts to deduce special cases such as `~/.ssh/*`.
    '';
  };
}
