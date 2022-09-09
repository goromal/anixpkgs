{ writeShellScriptBin
, callPackage
, color-prints
, strings
, pandoc
}:
let
    template_file = ./tex_templates/template.tex;
    name = "md2pdf";
    extension = "pdf";
    usage_str = ''
    usage: md2pdf input.md output.pdf

    Use LaTeX to convert a markdown file into a formatted pdf.
    '';
    optsWithVarsAndDefaults = [];
    convOptCmds = [
        { extension = "md|MD"; commands = ''
        tmpdir=$(mktemp -d)
        ${pandoc}/bin/pandoc -N --template="${template_file}" \
            --variable mainfont="Helvetica" \
            --variable sansfont="Helvetica" --variable monofont="Menlo" \
            --variable fontsize=20pt --variable version="0.0.0" \
            "$infile" --toc -o "$tmpdir/__output.pdf" && \
        mv "$tmpdir/__output.pdf" "$outfile"
        rm -rf $tmpdir
        ''; }
    ];
in callPackage ./mkConverter.nix {
    inherit writeShellScriptBin callPackage color-prints strings;
    inherit name extension usage_str optsWithVarsAndDefaults convOptCmds;
}
