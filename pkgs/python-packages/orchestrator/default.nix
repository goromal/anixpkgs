{ buildPythonPackage, makeWrapper, click, aapis-py, grpcio, colorama, mp4
, mp4unite, scrape, statsd, service-ports, setuptools, pkg-src }:
buildPythonPackage rec {
  pname = "orchestrator";
  version = "0.0.0";
  src = pkg-src;
  buildInputs = [ makeWrapper ];
  pyproject = true;
  build-system = [ setuptools ];
  propagatedBuildInputs =
    [ click aapis-py grpcio colorama mp4 mp4unite scrape statsd ];
  postInstall = ''
    wrapProgram $out/bin/orchestratord \
      --add-flags "--port ${builtins.toString service-ports.orchestrator}"
    wrapProgram $out/bin/orchestrator \
      --add-flags "--port ${builtins.toString service-ports.orchestrator}"
  '';
  doCheck = false;
  meta = {
    description =
      "Daemon + CLI for managing select background tasks on my computer.";
    longDescription = ''
      [Repository](https://github.com/goromal/orchestrator)

      ***Work in progress. Detailed description to come.***
    '';
  };
}
