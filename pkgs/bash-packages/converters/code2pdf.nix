{ writeShellScriptBin
, callPackage
, color-prints
, strings
, redirects
, ghostscript
, vim
}:
let
    name = "code2pdf";
    extension = "pdf";
    usage_str = ''
    usage: code2pdf infile output.pdf

    Convert plain text code infile to color-coded pdf outfile.

    Recursive search example for C++ files:
    for f in \$(find . -name '*.cpp' -or -name '*.h'); do code2pdf \$f \$f.pdf; done
    '';
    optsWithVarsAndDefaults = [];
    convOptCmds = [
        { extension = "*"; commands = ''
        tmpdir=$(mktemp -d)
        ${vim}/bin/vim "$infile" -c ":hardcopy > $tmpdir/_inter.ps" -c ":q" ${redirects.suppress_all}
        ${ghostscript}/bin/ps2pdf "$tmpdir/_inter.ps" "$outfile" ${redirects.suppress_all}
        rm -rf "$tmpdir"
        ''; }
    ];
in callPackage ./mkConverter.nix {
    inherit writeShellScriptBin callPackage color-prints strings;
    inherit name extension usage_str optsWithVarsAndDefaults convOptCmds;
    description = "Generate pretty-printed PDF files from source code files.";
}
