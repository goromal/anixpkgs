{ writeShellScriptBin
, callPackage
, color-prints
, redirects
, git-cc
}:
let
    pkgname = "cpp-helper";
    argparse = callPackage ../bash-utils/argparse.nix {
        usage_str = ''
        usage: ${pkgname} [options]

        Options:
        --make-format-file             Dumps a format rules file into .clang-format
        --make-nix                     Dump template default.nix and shell.nix files
        --make-exec-lib   CPPNAME      Generate a lib+exec package template
        --make-header-lib CPPNAME      Generate a header-only library template
        '';
        optsWithVarsAndDefaults = [
            { var = "makeff";  isBool = true;  default = "0"; flags = "--make-format-file"; }
            { var = "makehot"; isBool = false; default = "";  flags = "--make-header-lib"; }
            { var = "makeexl"; isBool = false; default = "";  flags = "--make-exec-lib"; }
            { var = "makenix"; isBool = true;  default = "0"; flags = "--make-nix"; }
        ];
    };
    printErr = "${color-prints}/bin/echo_red";
    printGrn = "${color-prints}/bin/echo_green";
    formatFile = ./res/clang-format;
    shellFile = ./res/_shell.nix;
    defaultFile = ./res/_default.nix;
    makeffRule = ''
    if [[ "$makeff" == "1" ]]; then
        ${printGrn} "Generating .clang-format..."
        cat ${formatFile} > .clang-format
    fi
    '';
    makenixRule = ''
    if [[ "$makenix" == "1" ]]; then
        ${printGrn} "Generating template default.nix and shell.nix files..."
        cat ${defaultFile} > default.nix
        cat ${shellFile} > shell.nix
    fi
    '';
    makehotRule = ''
    if [[ ! -z "$makehot" ]]; then
        if [[ -d "$makehot" ]]; then
            while true; do
                read -p "Destination directory exists ($makehot); remove? [yn] " yn
                case $yn in
                    [Yy]* ) rm -rf "$makehot"; break;;
                    [Nn]* ) echo "Aborting."; exit;;
                    * ) ${printErr} "Please respond y or n";;
                esac
            done
        fi
        ${printGrn} "Generating header-only boilerplate for $makehot..."
        git clone https://github.com/goromal/example-cpp "$tmpdir/example-cpp" ${redirects.suppress_all}
        ${git-cc}/bin/git-cc "$tmpdir/example-cpp" "$makehot" ${redirects.suppress_all}
        sed -i 's|example-cpp|'"$makehot"'|g' "$makehot/CMakeLists.txt"
        sed -i 's|example-cpp|'"$makehot"'|g' "$makehot/README.md"
        sed -i 's|example-cpp|'"$makehot"'|g' "$makehot/cmake/example-cppConfig.cmake.in"
        mv "$makehot/cmake/example-cppConfig.cmake.in" "$makehot/cmake/''${makehot}Config.cmake.in"
    fi
    '';
    makeexlRule = ''
    if [[ ! -z "$makeexl" ]]; then
        if [[ -d "$makeexl" ]]; then
            while true; do
                read -p "Destination directory exists ($makeexl); remove? [yn] " yn
                case $yn in
                    [Yy]* ) rm -rf "$makeexl"; break;;
                    [Nn]* ) echo "Aborting."; exit;;
                    * ) ${printErr} "Please respond y or n";;
                esac
            done
        fi
        ${printGrn} "Generating lib+exec package boilerplate for $makeexl..."
        git clone https://github.com/goromal/example-cpp2 "$tmpdir/example-cpp2" ${redirects.suppress_all}
        ${git-cc}/bin/git-cc "$tmpdir/example-cpp2" "$makeexl" ${redirects.suppress_all}
        sed -i 's|example-cpp|'"$makeexl"'|g' "$makeexl/CMakeLists.txt"
        sed -i 's|example-cpp|'"$makeexl"'|g' "$makeexl/README.md"
        sed -i 's|example-cpp|'"$makeexl"'|g' "$makeexl/cmake/example-cppConfig.cmake.in"
        mv "$makeexl/cmake/example-cppConfig.cmake.in" "$makeexl/cmake/''${makeexl}Config.cmake.in"
    fi
    '';
in writeShellScriptBin pkgname ''
    set -e
    ${argparse}
    tmpdir=$(mktemp -d)
    ${makeffRule}
    ${makehotRule}
    ${makeexlRule}
    ${makenixRule}
    rm -rf "$tmpdir"
''
