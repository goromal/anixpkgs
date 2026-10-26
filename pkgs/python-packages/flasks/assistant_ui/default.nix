{
  buildPythonPackage,
  setuptools,
  flask,
  werkzeug,
  pytestCheckHook,
  git,
  python,
  pkg-src,
}:
let
  pythonLibDir = "lib/python${python.passthru.pythonVersion}/site-packages";
in
buildPythonPackage rec {
  pname = "assistant_ui";
  version = "0.0.0";
  pyproject = true;
  build-system = [ setuptools ];
  src = "${pkg-src}/assistant_ui";
  prePatch = ''
    mkdir -p $out/${pythonLibDir}/templates
    cp main.html $out/${pythonLibDir}/templates/main.html
    mkdir -p $out/${pythonLibDir}/static
    cp assistant.js assistant.css $out/${pythonLibDir}/static/
  '';
  propagatedBuildInputs = [
    flask
    werkzeug
  ];
  # repo_status tests drive a real git repo.
  nativeCheckInputs = [
    pytestCheckHook
    git
  ];
  pytestFlags = [ "tests" ];
  meta = {
    description = "Assistant: a web console of agent sessions rooted in the second-brain repo.";
    longDescription = ''
      Spawns Claude/Codex sessions (tmux + ttyd) that all work in one durable
      checkout of [second-brain](https://github.com/goromal/second-brain), each
      preloaded with the private `assistant` skill.
    '';
    autoGenUsageCmd = "--help";
  };
}
