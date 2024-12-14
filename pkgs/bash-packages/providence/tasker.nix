{ writeArgparseScriptBin, color-prints, task-tools, providence }:
let
  pkgname = "providence-tasker";
  usage_str = ''
    usage: ${pkgname} [options] num_days

    Generate [num_days] tasks derived from providence output.

    Options:
    --wiki-url URL   URL of wiki to get data from (default: https://notes.andrewtorgesen.com)
  '';
  printErr = "${color-prints}/bin/echo_red";
  prexe = "${providence}/bin/providence";
  ttexe = "${task-tools}/bin/task-tools";
in (writeArgparseScriptBin pkgname usage_str [{
  var = "wiki_url";
  isBool = false;
  default = "https://notes.andrewtorgesen.com";
  flags = "--wiki-url";
}] ''
  if [[ -z "$1" ]]; then
      ${printErr} "num_days not specified."
      exit 1
  fi
  num_days="$1"
  for i in $(seq 1 $num_days); do
      duedate=$(date --date="$i days" +"%Y-%m-%d")
      echo "Creating task for $duedate..."
      taskname="P0: [T] $(${prexe} --wiki-url $wiki_url passage) - $(${prexe} --wiki-url $wiki_url talk)"
      tasknotes="$(${prexe} --wiki-url $wiki_url patriarchal)"
      ${ttexe} put --name="$taskname" --notes="$tasknotes" --date="$duedate"
  done
'') // {
  meta = {
    description = "Providence + Google Tasks integration.";
    longDescription = ''
      Takes output from `providence` and places it into `[num_days]` consecutive days of Google Tasks.

      Requires a wiki secrets file at `~/secrets/wiki/secrets.json` and a Google Tasks secrets file
      at `~/secrets/task/secrets.json`.
    '';
    autoGenUsageCmd = "--help";
  };
}
