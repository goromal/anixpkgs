{
  buildPythonPackage,
  setuptools,
  flask,
  pytestCheckHook,
  python,
  pkg-src,
}:
let
  pythonLibDir = "lib/python${python.passthru.pythonVersion}/site-packages";
in
buildPythonPackage rec {
  pname = "rcrsync_ui";
  version = "0.0.1";
  pyproject = true;
  build-system = [ setuptools ];
  src = "${pkg-src}/rcrsync_ui";
  prePatch = ''
    mkdir -p $out/${pythonLibDir}/templates
    cp templates/main.html $out/${pythonLibDir}/templates/main.html
  '';
  propagatedBuildInputs = [ flask ];
  nativeCheckInputs = [ pytestCheckHook ];
  pytestFlags = [ "tests" ];
  meta = {
    description = "Web UI to run rcrsync and see when each cloud directory was last pushed and pulled";
    longDescription = "Serves /rcrsync, which lists each rcrsync directory with the time of its last push (override, mirror or sync) and last pull (init, copy or sync), read from the rcrsync history file and seeded from rclone's bisync cache, and runs rcrsync commands on whole directories or subdirectories.";
    autoGenUsageCmd = "--help";
  };
}
