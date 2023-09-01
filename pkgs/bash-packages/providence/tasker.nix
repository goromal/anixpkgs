{ writeShellScriptBin, callPackage, color-prints, task-tools, providence }:
let
  pkgname = "providence-tasker";
  argparse = callPackage ../bash-utils/argparse.nix {
    usage_str = ''
      usage: ${pkgname} num_days

      Generate [num_days] tasks derived from providence output.
    '';
    optsWithVarsAndDefaults = [ ];
  };
  printErr = "${color-prints}/bin/echo_red";
  prexe = "${providence}/bin/providence";
  ttexe = "${task-tools}/bin/task-tools";
in (writeShellScriptBin pkgname ''
  ${argparse}
  if [[ -z "$1" ]]; then
      ${printErr} "num_days not specified."
      exit 1
  fi
  num_days="$1"
  for i in $(seq 1 $num_days); do
      duedate=$(date --date="$i days" +"%Y-%m-%d")
      echo "Creating task for $duedate..."
      taskname="$(${prexe} passage)"
      tasknotes="$(${prexe} patriarchal)"
      ${ttexe} put --name="$taskname" --notes="$tasknotes" --date="$duedate"
  done
'') // {
  meta = {
    description = "Providence + Google Tasks integration.";
    longDescription = ''
      Takes output from `providence` and places it into `[num_days]` consecutive days of Google Tasks.

      ```
      usage: providence-tasker num_days

      Generate [num_days] tasks derived from providence output.
      ```

      Requires a wiki secrets file at `~/secrets/wiki/secrets.json` and a Google Tasks secrets file
      at `~/secrets/task/secrets.json`.
    '';
  };
}
