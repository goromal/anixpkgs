let
  pkgs = import (fetchTarball
    ("https://github.com/goromal/anixpkgs/archive/refs/tags/vREPLACEME.tar.gz"))
    { };
in with pkgs;
mkShell {
  nativeBuildInputs = [ cmake ];
  buildInputs = [
    # ADD deps
  ];
  shellHook = ''
    # Generate IntelliSense-compatible config for code completion in VSCode
    mkdir -p .vscode
    export CPP_CFG_JSON=.vscode/c_cpp_properties.json
    echo "{ \"configurations\": [{\"name\":\"NixOS\",\"intelliSenseMode\":\"linux-gcc-x64\"," > $CPP_CFG_JSON
    echo "\"cStandard\":\"gnu17\",\"cppStandard\":\"gnu++17\",\"includePath\":[" >> $CPP_CFG_JSON
    echo $(echo $CMAKE_INCLUDE_PATH: | sed -re 's|([^:\n]+)[:\n]|\"\1\",\n|g') >> $CPP_CFG_JSON
    echo "\"\''${workspaceFolder}/src\"" >> $CPP_CFG_JSON
    echo "]}],\"version\":4}" >> $CPP_CFG_JSON
  '';
}
