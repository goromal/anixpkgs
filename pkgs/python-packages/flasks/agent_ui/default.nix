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
  pname = "agent-ui";
  version = "0.1.0";
  pyproject = true;
  build-system = [ setuptools ];
  src = "${pkg-src}/agent_ui";
  prePatch = ''
    mkdir -p $out/${pythonLibDir}/templates
    cp templates/main.html $out/${pythonLibDir}/templates/main.html
  '';
  propagatedBuildInputs = [ flask ];
  nativeCheckInputs = [ pytestCheckHook ];
  pytestFlagsArray = [ "tests" ];
  meta = {
    description = "Workspace-aware web launcher for Claude and Codex terminals.";
    longDescription = ''
      Provides an authenticated browser interface for starting and attaching to
      tmux-backed Claude and Codex sessions in configured devshell workspaces.
    '';
    autoGenUsageCmd = "--help";
  };
}
