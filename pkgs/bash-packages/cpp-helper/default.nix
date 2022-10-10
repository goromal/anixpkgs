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
        --make-header-lib CPPNAME      Generate a header-only library template
        --make-pybind-lib NAME,CPPNAME Generate a pybind package wrapping a header-only library
        '';
        optsWithVarsAndDefaults = [
            { var = "makeff"; isBool = true; default = "0"; flags = "--make-format-file"; }
            { var = "makehot"; isBool = false; default = ""; flags = "--make-header-lib"; }
            { var = "makepbl"; isBool = false; default = ""; flags = "--make-pybind-lib"; }
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
    makepblRule = ''
    if [[ ! -z "$makepbl" ]]; then
        if [[ "$makepbl" != *","* ]]; then
            ${printErr} "Pybind names not delimited by a comma"
            exit 1
        fi
        IFS=',' read -ra pblargs <<< "$makepbl"
        pblname="''${pblargs[0]}"
        cppname="''${pblargs[1]}"
        if [[ -z "$pblname" ]]; then
            ${printErr} "Pybind library name not specified"
            exit 1
        fi
        if [[ -z "$cppname" ]]; then
            ${printErr} "Wrapped c++ library name not specified"
            exit 1
        fi
        if [[ -d "$pblname" ]]; then
            while true; do
                read -p "Destination directory exists ($pblname); remove? [yn] " yn
                case $yn in
                    [Yy]* ) rm -rf "$pblname"; break;;
                    [Nn]* ) echo "Aborting."; exit;;
                    * ) ${printErr} "Please respond y or n";;
                esac
            done
        fi
        ${printGrn} "Generating pybind wrapper library boilerplate for $pblname wrapping $cppname..."
        git clone git@github.com:goromal/example_cpp_py.git "$tmpdir/example_cpp_py" ${redirects.suppress_all}
        ${git-cc}/bin/git-cc "$tmpdir/example_cpp_py" "$pblname" ${redirects.suppress_all}
        sed -i 's|example_cpp_py|'"$pblname"'|g' "$pblname/python_module.cpp"
        sed -i 's|example-cpp|'"$cppname"'|g' "$pblname/python_module.cpp"
        sed -i 's|example_cpp_py|'"$pblname"'|g' "$pblname/README.md"
        sed -i 's|example_cpp_py|'"$pblname"'|g' "$pblname/CMakeLists.txt"
        sed -i 's|example-cpp|'"$cppname"'|g' "$pblname/CMakeLists.txt"
    fi
    '';
in writeShellScriptBin pkgname ''
    ${argparse}
    tmpdir=$(mktemp -d)
    ${makeffRule}
    ${makehotRule}
    ${makepblRule}
    rm -rf "$tmpdir"
''
