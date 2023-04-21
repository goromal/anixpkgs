{ writeShellScriptBin
, callPackage
, color-prints
, redirects
, strings
, git-cc
}:
let
    pkgname = "py-helper";
    argparse = callPackage ../bash-utils/argparse.nix {
        usage_str = ''
        usage: ${pkgname} [options]

        Options:
        --make-pkg        NAME         Generate a template python package
        --make-pybind-lib NAME,CPPNAME Generate a pybind package wrapping a header-only library
        --make-nix                     Dump template default.nix and shell.nix files
        '';
        optsWithVarsAndDefaults = [
            { var = "makepkg"; isBool = false; default = "";  flags = "--make-pkg"; }
            { var = "makepbl"; isBool = false; default = "";  flags = "--make-pybind-lib"; }
            { var = "makenix"; isBool = true;  default = "0"; flags = "--make-nix"; }
        ];
    };
    printErr = "${color-prints}/bin/echo_red";
    printGrn = "${color-prints}/bin/echo_green";
    shellFile = ./res/_shell.nix;
    defaultFile = ./res/_default.nix;
    makenixRule = ''
    if [[ "$makenix" == "1" ]]; then
        ${printGrn} "Generating template default.nix and shell.nix files..."
        cat ${defaultFile} > default.nix
        cat ${shellFile} > shell.nix
    fi
    '';
    makepkgRule = ''
    if [[ ! -z "$makepkg" ]]; then
        if [[ -d "$makepkg" ]]; then
            while true; do
                read -p "Destination directory exists ($makepkg); remove? [yn] " yn
                case $yn in
                    [Yy]* ) rm -rf "$makepkg"; break;;
                    [Nn]* ) echo "Aborting."; exit;;
                    * ) ${printErr} "Please respond y or n";;
                esac
            done
        fi
        ${printGrn} "Generating Python package template for $makepkg..."
        git clone git@github.com:goromal/example_py.git "$tmpdir/example-py" ${redirects.suppress_all}
        ${git-cc}/bin/git-cc "$tmpdir/example-py" "$makepkg" ${redirects.suppress_all}
        sed -i 's|example-py|'"$makepkg"'|g' "$makepkg/README.md"
        sed -i 's|example-py|'"$makepkg"'|g' "$makepkg/setup.py"
        makepkgSnake="$(${strings.kebabToSnake} $makepkg)"
        sed -i 's|example_py|'"$makepkgSnake"'|g' "$makepkg/setup.py"
        sed -i 's|example_py|'"$makepkgSnake"'|g' "$makepkg/example_py/__version__.py"
        mv "$makepkg/example_py" "$makepkg/$makepkgSnake"
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
    set -e
    ${argparse}
    tmpdir=$(mktemp -d)
    ${makepkgRule}
    ${makepblRule}
    ${makenixRule}
    rm -rf "$tmpdir"
''
