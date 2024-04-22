{ buildPythonPackage, flask, werkzeug, writeShellScript, python }:
let pythonLibDir = "lib/python${python.passthru.pythonVersion}/site-packages";
in buildPythonPackage rec {
  pname = "atrs";
  version = "0.0.0";
  src = ./.;
  propagatedBuildInputs = [ flask werkzeug ];
  meta = {
    description = "REST server for machine management.";
    longDescription = ''
      ```bash
      usage: atrs [-h] [--port PORT]

      optional arguments:
        -h, --help           show this help message and exit
        --port PORT          Port to run the REST server on
      ```

      Hit up the server with e.g.,

      ```bash
      $ curl 'http://127.0.0.1:PORT/test?key=YOUR_KEY&payload=YOUR_PAYLOAD'

      {"error":"Invalid key provided."}
      ```
    '';
  };
}
