{
  buildPythonPackage,
  setuptools,
  flask,
  flask-login,
  werkzeug,
  pytestCheckHook,
  python,
  pkg-src,
}:
let
  pythonLibDir = "lib/python${python.passthru.pythonVersion}/site-packages";
in
buildPythonPackage rec {
  pname = "agent-ui";
  version = "0.1.0";
  pyproject = true;
  build-system = [ setuptools ];
  src = "${pkg-src}/agent_ui";
  prePatch = ''
    mkdir -p $out/${pythonLibDir}/templates
    cp templates/*.html $out/${pythonLibDir}/templates/
  '';
  propagatedBuildInputs = [
    flask
    flask-login
    werkzeug
  ];
  nativeCheckInputs = [ pytestCheckHook ];
  pytestFlagsArray = [ "tests" ];
  meta = {
    description = "Web console for devshell workspaces and agent terminals.";
    longDescription = ''
      Provides an authenticated browser interface for managing devshell
      workspaces and attaching to tmux-backed shell, Claude, and Codex sessions.
    '';
    autoGenUsageCmd = "--help";
  };
}
