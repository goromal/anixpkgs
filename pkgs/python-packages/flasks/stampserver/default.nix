{ buildPythonPackage, flask, strings, writeTextFile, callPackage
, writeShellScript, python }:
callPackage ../builders/mkSimpleFlaskApp.nix {
  pname = "stampserver";
  version = "0.0.0";
  inherit buildPythonPackage flask writeTextFile writeShellScript python;
  scriptPropagatedBuildInputs = [ ];
  overrideFullFlaskScript = true;
  flaskScript = builtins.readFile ./server.py;
  templateText = builtins.readFile ./index.html;
  description = "Provides an interface for stamping metadata on PNGs and MP4s.";
  longDescription = ''
    ```bash
    usage: stampserver [-h] [--port PORT] [--data-dir DATA_DIR]

    optional arguments:
      -h, --help           show this help message and exit
      --port PORT          Port to run the server on
      --data-dir DATA_DIR  Directory containing the stampable elements
    ```
  '';
}
