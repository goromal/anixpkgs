{ buildPythonPackage
, flask
, pysorting
, strings
, redirects
, writeTextFile
, callPackage
, writeShellScript
, python
}:
callPackage ../builders/mkSimpleFlaskApp.nix {
    pname = "rankserver";
    version = "0.0.1";
    inherit buildPythonPackage flask writeTextFile writeShellScript python;
    scriptPropagatedBuildInputs = [ pysorting ];
    overrideFullFlaskScript = true;
    flaskScript = builtins.readFile ./server.py;
    templateText = builtins.readFile ./index.html;
    description = "A portable webserver for ranking files via binary manual comparisons, powered by Python's flask library.";
    longDescription = ''
    ```bash
    usage: rankserver [-h] [--port PORT]
                  [--data-dir DATA_DIR]

    optional arguments:
    -h, --help     show this help
                    message and exit
    --port PORT    Port to run the
                    server on
    --data-dir DATA_DIR
                    Directory containing
                    the rankable
                    elements
    ```

    Spins up a flask webserver (on the specified port) whose purpose is to help a user rank files in the chosen `data-dir` directory via manual binary comparisons. The ranking is done via an incremental "RESTful" sorting strategy implemented within the [pysorting](./pysorting.md) library. State is created and maintained within the `data-dir` directory so that the ranking exercise can pick back up where it left off between different spawnings of the server. At this point, only the ranking of `.txt` and `.png` files is possible; other file types in `data-dir` will be ignored.    
    '';
}
