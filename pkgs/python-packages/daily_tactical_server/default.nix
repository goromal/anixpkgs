{ buildPythonPackage, pkg-src, lib, makeWrapper, click, aapis-py, grpcio, flask
, colorama, statsd, aiosqlite, aiofiles, wiki-tools, task-tools, service-ports
}:
buildPythonPackage rec {
  pname = "daily_tactical_server";
  version = "0.0.0";
  src = pkg-src;
  buildInputs = [ makeWrapper ];
  propagatedBuildInputs = [
    click
    aapis-py
    grpcio
    flask
    colorama
    statsd
    aiosqlite
    aiofiles
    wiki-tools
    task-tools
  ];
  postInstall = ''
    wrapProgram $out/bin/tacticald \
      --add-flags "--server-port ${
        builtins.toString service-ports.tactical.insecure
      } --web-port ${builtins.toString service-ports.tactical.web}"
    wrapProgram $out/bin/tactical \
      --add-flags "--server-port ${
        builtins.toString service-ports.tactical.insecure
      }"
  '';
  doCheck = false;
  meta = {
    description = "Daemon + CLI for managing a daily tactical webpage.";
    longDescription = ''
      [Repository](https://github.com/goromal/daily_tactical_server)
    '';
  };
}
