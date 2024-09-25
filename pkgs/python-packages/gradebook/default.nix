{ buildPythonPackage, makeWrapper, click, aapis-py, grpcio, colorama, service-ports, pkg-src }:
buildPythonPackage rec {
  pname = "gradebook";
  version = "0.0.0";
  src = pkg-src;
  buildInputs = [ makeWrapper ];
  propagatedBuildInputs =
    [ click aapis-py grpcio colorama ];
  postInstall = ''
    wrapProgram $out/bin/gradebookd \
      --add-flags "--port ${builtins.toString service-ports.gradebook}"
    wrapProgram $out/bin/gradebook \
      --add-flags "--port ${builtins.toString service-ports.gradebook}"
  '';
  doCheck = false;
  meta = {
    description =
      "Daemon + CLI for managing a database of software requirements and corresponding software test results.";
    longDescription = ''
      [Repository](https://github.com/goromal/gradebook)
    '';
  };
}
