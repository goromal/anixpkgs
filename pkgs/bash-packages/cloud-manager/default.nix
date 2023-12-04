{ writeShellScriptBin, callPackage, color-prints, defaultCsv ? "NULL" }:
let
  pkgname = "cloud-manager";
  argparse = callPackage ../bash-utils/argparse.nix {
    usage_str = ''
      usage: ${pkgname} [options] cmd

      Manage cloud storage directories.

      Options:
      --dirs-csv    CSV specifying all directories to sync (Default: ${defaultCsv}).

      Commands:
      sync-all      Sync all directories.
      sync DIRNAME  Sync a specific directory from the CSV.
    '';
    optsWithVarsAndDefaults = [
      {
        var = "dirscsv";
        isBool = false;
        default = defaultCsv;
        flags = "--dirs-csv";
      }
    ];
  };
  printErr = "${color-prints}/bin/echo_red";
  printGrn = "${color-prints}/bin/echo_green";
in (writeShellScriptBin pkgname ''
  ${argparse}
  # ^^^^ TODO
'') // {
  meta = {
    description = "Manage cloud storage directories.";
    longDescription = ''
    ```bash
    usage: ${pkgname} [options] cmd

    Options:
    --dirs-csv    CSV specifying all directories to sync. (REQUIRED)

    Commands:
    sync-all      Sync all directories.
    sync DIRNAME  Sync a specific directory from the CSV.
    ```
    '';
  };
}
