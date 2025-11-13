{ stdenv, writeArgparseScriptBin, color-prints, redirects, wiki-tools, sread
, browserExec }:
let
  printErr = "${color-prints}/bin/echo_red";
  wikiuser = "$(cat $HOME/secrets/wiki/u.txt)";
  wikipass = "$(${sread}/bin/sread $HOME/secrets/wiki/p.txt.tyz)";
  anix-compare = writeArgparseScriptBin "anix-compare" ''
    usage: anix-compare TAG1 TAG2

    Compare anixpkgs versions TAG1 (e.g., 1.0.0) and TAG2 (e.g., 2.0.0) in the browser.
  '' [ ] ''
    if [[ -z $1 ]]; then
        ${printErr} "TAG1 not specified."
        exit 1
    fi
    if [[ -z $2 ]]; then
        ${printErr} "TAG2 not specified."
        exit 1
    fi
    ${browserExec} "https://github.com/goromal/anixpkgs/compare/v$1...v$2" ${redirects.suppress_all}
  '';
  open-notes = writeArgparseScriptBin "open-notes" ''
    usage: open-notes ID1 [ID2 ID3 ...]

    Open note ID's ID1, ID2, ... in the browser.
  '' [ ] ''
    if [[ -z $1 ]]; then
        ${printErr} "No note ID specified."
        exit 1
    fi
    urls=$(for i in $@; do echo "https://notes.andrewtorgesen.com/doku.php?id=$i"; done)
    ${browserExec} $urls ${redirects.suppress_all}
  '';
  triage = writeArgparseScriptBin "triage-and-action" ''
    usage: triage-and-action

    Open all pages needed for the triaging and actioning processes in the browser.
  '' [ ] ''
    ITAR_PAGE="https://www.notion.so/P0-Andrew-s-ITAR-Productivity-Workflow-ba01b8f950e64c16aace094c1e3c07f6"
    ITNS_PAGE="https://www.notion.so/ITNS-3ea6f1aa43564b0386bcaba6c7b79870"
    TRELLO_PAGE="https://trello.com/w/workspace69213858"
    TASKS_PAGE="https://calendar.google.com/calendar/u/0/r/tasks"
    ${browserExec} $ITAR_PAGE $ITNS_PAGE $TRELLO_PAGE $TASKS_PAGE ${redirects.suppress_all}
  '';
  a4s = writeArgparseScriptBin "a4s" ''
    usage: a4s PRIORITY DESCRIPTION

    Create an A4S ticket with priority level PRIORITY (e.g., 0, 1, 2, ...) and
    description DESCRIPTION. Also open up a link to the ticket in the browser.
  '' [ ] ''
    if [[ -z $1 ]]; then
        ${printErr} "No priority specified."
        exit 1
    fi
    if [[ -z "$2" ]]; then
        ${printErr} "No ticket description given."
        exit 1
    fi
    idx=$(${wiki-tools}/bin/wiki-tools --wiki_user ${wikiuser} --wiki_pass ${wikipass} get --page-id a4s:internal:idx)
    idx=$((idx+1))
    tmpdir=$(mktemp -d)
    echo "====== [P''${1}] A4S-''${idx}: ''${2} ======" > $tmpdir/ticket.txt
    echo -e "\n" >> $tmpdir/ticket.txt
    echo -e "==== Description ====\n\n  * ...\n\n==== Requirements ====\n\n  * ...\n\n==== PRs ====\n\n  * ...\n\n==== Miscellaneous ====\n\n  * ...\n\n" >> $tmpdir/ticket.txt
    ${wiki-tools}/bin/wiki-tools --wiki_user ${wikiuser} --wiki_pass ${wikipass} put --page-id a4s:backlog:a4s''${idx} --file $tmpdir/ticket.txt
    ${wiki-tools}/bin/wiki-tools --wiki_user ${wikiuser} --wiki_pass ${wikipass} put --page-id a4s:internal:idx --content "$idx"
    rm -rf $tmpdir
    ${browserExec} "https://notes.andrewtorgesen.com/doku.php?id=a4s:backlog:a4s''${idx}" ${redirects.suppress_all}
  '';
in stdenv.mkDerivation {
  name = "browser-aliases";
  version = "1.0.0";
  unpackPhase = "true";
  installPhase = ''
    mkdir -p                            $out/bin
    cp ${anix-compare}/bin/anix-compare $out/bin
    cp ${open-notes}/bin/open-notes     $out/bin
    cp ${triage}/bin/triage-and-action  $out/bin
    cp ${a4s}/bin/a4s                   $out/bin
  '';
}
