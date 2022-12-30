{ buildPythonApplication
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
    version = "0.0.0";
    inherit buildPythonApplication flask writeTextFile writeShellScript python;
    scriptPropagatedBuildInputs = [ pysorting ];
    flaskScript = builtins.readFile ./server.py;
    templateText = builtins.readFile ./index.html;
    helperScript = ''
    '';
}
