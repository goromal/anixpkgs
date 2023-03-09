{ stdenv
, callPackage
, writeShellScriptBin
, color-prints
, browserExec
}:
let
    printErr = "${color-prints}/bin/echo_red";
    anix-argparse = callPackage ../bash-utils/argparse.nix {
        usage_str = ''
        usage: anix-compare TAG1 TAG2

        Compare anixpkgs versions TAG1 (e.g., 1.0.0) and TAG2 (e.g., 2.0.0) in the browser.
        '';
        optsWithVarsAndDefaults = [];
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
        ${browserExec} "https://github.com/goromal/anixpkgs/compare/v$1...v$2"
    '';
    open-notes-argparse = callPackage ../bash-utils/argparse.nix {
        usage_str = ''
        usage: open-notes ID1 [ID2 ID3 ...]

        Open note ID's ID1, ID2, ... in the browser.
        '';
        optsWithVarsAndDefaults = [];
    };
    open-notes = writeShellScriptBin "open-notes" ''
        ${open-notes-argparse}
        if [[ -z $1 ]]; then
            ${printErr} "No note ID specified."
            exit 1
        fi
        urls=$(for i in $@; do echo "https://notes.andrewtorgesen.com/doku.php?id=$i"; done)
        ${browserExec} $urls
    '';
in stdenv.mkDerivation {
    name = "browser-aliases";
    version = "1.0.0";
    unpackPhase = "true";
    installPhase = ''
        mkdir -p                            $out/bin
        cp ${anix-compare}/bin/anix-compare $out/bin
        cp ${open-notes}/bin/open-notes     $out/bin
    '';
}
