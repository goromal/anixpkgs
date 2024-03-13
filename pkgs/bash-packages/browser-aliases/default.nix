{ stdenv, callPackage, writeShellScriptBin, color-prints, redirects, wiki-tools
, browserExec }:
let
  printErr = "${color-prints}/bin/echo_red";
  doBrowserExec = exec: url: if exec == null then ''
    echo "URL ${url}"
  '' else ''
    ${exec} ${url} ${redirects.suppress_all}
  '';
  anix-argparse = callPackage ../bash-utils/argparse.nix {
    usage_str = ''
      usage: anix-compare TAG1 TAG2

      Compare anixpkgs versions TAG1 (e.g., 1.0.0) and TAG2 (e.g., 2.0.0) in the browser.
    '';
    optsWithVarsAndDefaults = [ ];
  };
  anix-compare = writeShellScriptBin "anix-compare" ''
    ${anix-argparse}
    if [[ -z $1 ]]; then
        ${printErr} "TAG1 not specified."
        exit 1
    fi
    if [[ -z $2 ]]; then
        ${printErr} "TAG2 not specified."
        exit 1
    fi
    ${doBrowserExec browserExec "https://github.com/goromal/anixpkgs/compare/v$1...v$2"}
  '';
  open-notes-argparse = callPackage ../bash-utils/argparse.nix {
    usage_str = ''
      usage: open-notes ID1 [ID2 ID3 ...]

      Open note ID's ID1, ID2, ... in the browser.
    '';
    optsWithVarsAndDefaults = [ ];
  };
  open-notes = writeShellScriptBin "open-notes" ''
    ${open-notes-argparse}
    if [[ -z $1 ]]; then
        ${printErr} "No note ID specified."
        exit 1
    fi
    urls=$(for i in $@; do echo "https://notes.andrewtorgesen.com/doku.php?id=$i"; done)
    ${doBrowserExec browserExec "$urls"}
  '';
  a4s-argparse = callPackage ../bash-utils/argparse.nix {
    usage_str = ''
      usage: a4s PRIORITY DESCRIPTION

      Create an A4S ticket with priority level PRIORITY (e.g., 0, 1, 2, ...) and
      description DESCRIPTION. Also open up a link to the ticket in the browser.
    '';
    optsWithVarsAndDefaults = [ ];
  };
  a4s = writeShellScriptBin "a4s" ''
    ${a4s-argparse}
    if [[ -z $1 ]]; then
        ${printErr} "No priority specified."
        exit 1
    fi
    if [[ -z "$2" ]]; then
        ${printErr} "No ticket description given."
        exit 1
    fi
    idx=$(${wiki-tools}/bin/wiki-tools get --page-id a4s:internal:idx)
    idx=$((idx+1))
    tmpdir=$(mktemp -d)
    echo "====== [P''${1}] A4S-''${idx}: ''${2} ======" > $tmpdir/ticket.txt
    echo -e "\n" >> $tmpdir/ticket.txt
    echo -e "==== Description ====\n\n  * ...\n\n==== Requirements ====\n\n  * ...\n\n==== PRs ====\n\n  * ...\n\n==== Miscellaneous ====\n\n  * ...\n\n" >> $tmpdir/ticket.txt
    ${wiki-tools}/bin/wiki-tools put --page-id a4s:backlog:a4s''${idx} --file $tmpdir/ticket.txt
    ${wiki-tools}/bin/wiki-tools put --page-id a4s:internal:idx --content "$idx"
    rm -rf $tmpdir
    ${doBrowserExec browserExec "https://notes.andrewtorgesen.com/doku.php?id=a4s:backlog:a4s''${idx}"}
  '';
in stdenv.mkDerivation {
  name = "browser-aliases";
  version = "1.0.0";
  unpackPhase = "true";
  installPhase = ''
    mkdir -p                            $out/bin
    cp ${anix-compare}/bin/anix-compare $out/bin
    cp ${open-notes}/bin/open-notes     $out/bin
    cp ${a4s}/bin/a4s                   $out/bin
  '';
}
