{ writeArgparseScriptBin, color-prints, redirects, git-cc, anixpkgs-version }:
let
  pkgname = "cpp-helper";
  usage_str = ''
    usage: ${pkgname} [options]

    Options:
        make       TARGET|all   Full CMake build command (run from repo root)
        format-file             Dumps a format rules file into .clang-format
        nix                     Dump template default.nix and shell.nix files
        exec-lib   CPPNAME      Generate a lib+exec package template
        header-lib CPPNAME      Generate a header-only library template
        vscode                  Generate VSCode C++ header detection settings file
  '';
  printErr = "${color-prints}/bin/echo_red";
  printGrn = "${color-prints}/bin/echo_green";
  formatFile = ./res/clang-format;
  shellFile = ./res/_shell.nix;
  defaultFile = ./res/_default.nix;
  makeRule = ''
    if [[ ! -z "$maketarget" ]]; then
      if [[ "$maketarget" == "all" ]]; then
        maketarget=""
      fi
      ${printGrn} "Building your repo..."
      if [[ ! -f CMakeLists.txt ]]; then
        ${printErr} "CMakeLists.txt not found."
        exit 1
      fi
      if [[ -f shell.nix ]]; then
        nix-shell --command 'NIX_CFLAGS_COMPILE= cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=1 -DCMAKE_C_FLAGS="$NIX_CFLAGS_COMPILE" -DCMAKE_CXX_FLAGS="$NIX_CFLAGS_COMPILE" && make -C build -j$(nproc) '$maketarget
      elif [[ -f flake.nix ]]; then
        nix develop --command bash -c 'NIX_CFLAGS_COMPILE= cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=1 -DCMAKE_C_FLAGS="$NIX_CFLAGS_COMPILE" -DCMAKE_CXX_FLAGS="$NIX_CFLAGS_COMPILE" && make -C build -j$(nproc) '$maketarget
      else
        ${printErr} "shell.nix not found."
        exit 1
      fi
    fi
  '';
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
        echo "], \"compileCommands\": \"build/compile_commands.json\" }],\"version\":4}" >> $CPP_CFG_JSON
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
    flags = "format-file";
  }
  {
    var = "makehot";
    isBool = false;
    default = "";
    flags = "header-lib";
  }
  {
    var = "makeexl";
    isBool = false;
    default = "";
    flags = "exec-lib";
  }
  {
    var = "makenix";
    isBool = true;
    default = "0";
    flags = "nix";
  }
  {
    var = "makevscode";
    isBool = true;
    default = "0";
    flags = "vscode";
  }
  {
    var = "maketarget";
    isBool = false;
    default = "";
    flags = "make";
  }
] ''
  set -e
  tmpdir=$(mktemp -d)
  ${makeffRule}
  ${makehotRule}
  ${makeexlRule}
  ${makenixRule}
  ${makevscodeRule}
  ${makeRule}
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
