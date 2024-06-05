{ writeArgparseScriptBin, color-prints, redirects, git-cc, anixpkgs-version }:
let
  pkgname = "cpp-helper";
  usage_str = ''
    usage: ${pkgname} [options]

    Options:
    --make-format-file             Dumps a format rules file into .clang-format
    --make-nix                     Dump template default.nix and shell.nix files
    --make-exec-lib   CPPNAME      Generate a lib+exec package template
    --make-header-lib CPPNAME      Generate a header-only library template
    --make-vscode                  Generate VSCode C++ header detection settings file
  '';
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
        sed -i 's|REPLACEME|${anixpkgs-version}|g' default.nix
        cat ${shellFile} > shell.nix
        sed -i 's|REPLACEME|${anixpkgs-version}|g' shell.nix
    fi
  '';
  makevscodeRule = ''
    if [[ "$makevscode" == "1" ]]; then
        export CPP_CFG_JSON=.vscode/c_cpp_properties.json
        ${printGrn} "Generating IntelliSense-compatible config for code completion in VSCode ($CPP_CFG_JSON)..."
        mkdir -p .vscode
        echo "{ \"configurations\": [{\"name\":\"NixOS\",\"intelliSenseMode\":\"linux-gcc-x64\"," > $CPP_CFG_JSON
        echo "\"cStandard\":\"gnu17\",\"cppStandard\":\"gnu++17\",\"includePath\":[" >> $CPP_CFG_JSON
        echo $(echo $CMAKE_INCLUDE_PATH: | sed -re 's|([^:\n]+)[:\n]|\"\1\",\n|g') >> $CPP_CFG_JSON
        echo "\"\''${workspaceFolder}/src\"" >> $CPP_CFG_JSON
        echo "]}],\"version\":4}" >> $CPP_CFG_JSON
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
in (writeArgparseScriptBin pkgname usage_str [
  {
    var = "makeff";
    isBool = true;
    default = "0";
    flags = "--make-format-file";
  }
  {
    var = "makehot";
    isBool = false;
    default = "";
    flags = "--make-header-lib";
  }
  {
    var = "makeexl";
    isBool = false;
    default = "";
    flags = "--make-exec-lib";
  }
  {
    var = "makenix";
    isBool = true;
    default = "0";
    flags = "--make-nix";
  }
  {
    var = "makevscode";
    isBool = true;
    default = "0";
    flags = "--make-vscode";
  }
] ''
  set -e
  tmpdir=$(mktemp -d)
  ${makeffRule}
  ${makehotRule}
  ${makeexlRule}
  ${makenixRule}
  ${makevscodeRule}
  rm -rf "$tmpdir"
'') // {
  meta = {
    description = "Convenience tools for setting up C++ projects.";
    longDescription = ''
      ```
      ${usage_str}
      ```
    '';
  };
}
