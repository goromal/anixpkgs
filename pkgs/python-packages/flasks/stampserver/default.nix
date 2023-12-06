{ buildPythonPackage, flask, strings
, writeTextFile, callPackage, writeShellScript, python }:
callPackage ../builders/mkSimpleFlaskApp.nix {
  pname = "flask_stamper";
  version = "0.0.0";
  inherit buildPythonPackage flask writeTextFile writeShellScript python;
  scriptPropagatedBuildInputs = [ ];
  overrideFullFlaskScript = true;
  flaskScript = builtins.readFile ./server.py;
  templateText = builtins.readFile ./index.html;
  description = "Provides an interface for stamping metadata on PNGs and MP4s.";
  longDescription = ''
    ^^^^ TODO
  '';
}
