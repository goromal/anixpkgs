{ buildPythonPackage, click, aapis-py, grpcio, colorama, pkg-src }:
buildPythonPackage rec {
  pname = "orchestrator";
  version = "0.0.0";
  src = pkg-src;
  propagatedBuildInputs = [ click aapis-py grpcio colorama ];
  doCheck = false;
  meta = {
    description =
      "Daemon + CLI for managing select background tasks on my computer.";
    longDescription = ''
      [Repository](https://github.com/goromal/orchestrator)

      ***Work in progress***
    '';
  };
}
