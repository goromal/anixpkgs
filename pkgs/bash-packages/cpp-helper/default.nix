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
        --make-format-file       Dumps a format rules file into ./.clang-format
        --make-header-lib NAME   Generate a header-only library template
        '';
        optsWithVarsAndDefaults = [
            { var = "makeff"; isBool = true; default = "0"; flags = "--make-format-file"; }
            { var = "makehot"; isBool = false; default = ""; flags = "--make-header-lib"; }
        ];
    };
    printErr = "${color-prints}/bin/echo_red";
    printGrn = "${color-prints}/bin/echo_green";
    formatFile = ./res/clang-format;
    makeffRule = ''
    if [[ "$makeff" == "1" ]]; then
        ${printGrn} "Generating .clang-format..."
        cat ${formatFile} > .clang-format
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
        git clone git@github.com:goromal/example-cpp.git "$tmpdir/example-cpp" ${redirects.suppress_all}
        ${git-cc}/bin/git-cc "$tmpdir/example-cpp" "$makehot" ${redirects.suppress_all}
        sed -i 's|example-cpp|'"$makehot"'|g' "$makehot/CMakeLists.txt"
        sed -i 's|example-cpp|'"$makehot"'|g' "$makehot/README.md"
        sed -i 's|example-cpp|'"$makehot"'|g' "$makehot/cmake/example-cppConfig.cmake.in"
        mv "$makehot/cmake/example-cppConfig.cmake.in" "$makehot/cmake/''${makehot}Config.cmake.in"
    fi
    '';
in writeShellScriptBin pkgname ''
    ${argparse}
    tmpdir=$(mktemp -d)
    ${makeffRule}
    ${makehotRule}
    rm -rf "$tmpdir"
''
