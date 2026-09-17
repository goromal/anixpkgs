{
  buildPythonPackage,
  setuptools,
  pytestCheckHook,
  flask,
  ichabod,
  python,
  pkg-src,
}:
let
  pythonLibDir = "lib/python${python.passthru.pythonVersion}/site-packages";
in
buildPythonPackage rec {
  pname = "brom";
  version = "0.0.0";
  pyproject = true;
  build-system = [ setuptools ];
  src = "${pkg-src}/brom";
  prePatch = ''
    mkdir -p $out/${pythonLibDir}/templates
    cp templates/index.html $out/${pythonLibDir}/templates/index.html
  '';
  # brom shells out to ichabod for search. aria2 is deliberately absent: the
  # server never execs aria2c, it talks to the daemon over JSON-RPC, and the
  # systemd unit references ${pkgs.aria2}/bin/aria2c directly.
  makeWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    "${ichabod}/bin"
  ];
  propagatedBuildInputs = [ flask ];
  nativeCheckInputs = [ pytestCheckHook ];
  meta = {
    description = "Web UI for searching and downloading torrents via aria2.";
    longDescription = "";
    autoGenUsageCmd = "--help";
  };
}
