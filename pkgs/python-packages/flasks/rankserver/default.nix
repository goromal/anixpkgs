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
}
