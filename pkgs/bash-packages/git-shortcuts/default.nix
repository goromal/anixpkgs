{
  stdenv,
  writeArgparseScriptBin,
  color-prints,
}:
let
  printError = "${color-prints}/bin/echo_red";
  printYellow = "${color-prints}/bin/echo_yellow";
  gitcop =
    let
      pkgname = "gitcop";
    in
    writeArgparseScriptBin pkgname
      ''
        usage: ${pkgname} [-f] [branch_name]

        "Git CheckOut and Pull." Assumes remote is named origin. Optional -f flag fetches first.
        If no branch_name is provided, then only a pull will occur.
      ''
      [
        {
          var = "fetch";
          isBool = true;
          default = "0";
          flags = "-f";
        }
      ]
      ''
        currentbranch="$(git rev-parse --abbrev-ref HEAD)"
        if [[ -z "$currentbranch" ]]; then
            ${printError} "Must be run within a Git repository with a current branch."
            exit 1
        fi
        if [[ -z "$1" ]]; then
            ${printYellow} "git pull origin $currentbranch"
            git pull origin "$currentbranch"
            exit
        fi
        pause_secs=1
        if [[ "$fetch" == "1" ]]; then
            ${printYellow} "git fetch origin $1 && git checkout $1 && git pull origin $1"
            git fetch origin "$1" && sleep $pause_secs && git checkout "$1" && sleep $pause_secs && git pull origin "$1"
        else
            ${printYellow} "git checkout $1 && git pull origin $1"
            git checkout "$1" && sleep $pause_secs && git pull origin "$1"
        fi
      '';
  githead =
    let
      pkgname = "githead";
    in
    writeArgparseScriptBin pkgname
      ''
        usage: ${pkgname} [repo_path]

        Gets the commit hash of the HEAD of the current (or specified) repo path.
      ''
      [ ]
      ''
        if [[ ! -z "$1" ]]; then
          cd "$1"
        fi
        git log | head -1 | sed 's/.* //'
      '';
  gitcm =
    let
      pkgname = "gitcm";
    in
    writeArgparseScriptBin pkgname
      ''
        usage: ${pkgname} commit message ...

        "Git CoMmit, push, and get head revision." No quotes needed for commit message.
      ''
      [ ]
      ''
        currentbranch="$(git rev-parse --abbrev-ref HEAD)"
        if [[ -z "$currentbranch" ]]; then
          ${printError} "Must be run within a Git repository with a current branch."
          exit 1
        fi
        if [[ -z "$1" ]]; then
          ${printError} "Must provide a commit message (no quotes needed)"
          exit 1
        fi
        ${printYellow} "git cm \"$@\" && git push && githead"
        words=""
        for word in "$@"; do
          words+="$word "
        done
        words=''${words% }
        git cm "$words" && git push && githead
      '';
in
stdenv.mkDerivation {
  name = "git-shortcuts";
  version = "1.0.0";
  unpackPhase = "true";
  installPhase = ''
    mkdir -p                  $out/bin
    cp ${gitcop}/bin/gitcop   $out/bin
    cp ${githead}/bin/githead $out/bin
    cp ${gitcm}/bin/gitcm     $out/bin
  '';
  meta = {
    description = "Git shortcut commands.";
    longDescription = "";
    autoGenUsageCmd = "--help";
  };
}
