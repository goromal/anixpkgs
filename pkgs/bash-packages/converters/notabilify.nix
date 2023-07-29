{ writeShellScriptBin
, callPackage
, color-prints
, strings
, redirects
, ocamlPackages
}:
let
    cpdf = "${ocamlPackages.cpdf}/bin/cpdf";
    name = "notabilify";
    extension = "pdf";
    usage_str = ''
    usage: notabilify input.pdf output.pdf

    Takes a portrait PDF file and adds a large blank space to the right of every page for taking notes.
    '';
    optsWithVarsAndDefaults = [];
    convOptCmds = [
        { extension = "pdf|PDF"; commands = ''
        tmpdir=$(mktemp -d)
        ${cpdf} -scale-to-fit a4landscape "$infile" -o "$tmpdir/_intermediate.pdf" # ${redirects.suppress_all}
        ${cpdf} -shift "-190 0" "$tmpdir/_intermediate.pdf" -o "$outfile" # ${redirects.suppress_all}
        rm -rf "$tmpdir"
        ''; }
    ];
in callPackage ./mkConverter.nix {
    inherit writeShellScriptBin callPackage color-prints strings;
    inherit name extension usage_str optsWithVarsAndDefaults convOptCmds;
    description = "Make any PDF document suitable for note taking in e.g., Notability.";
}
