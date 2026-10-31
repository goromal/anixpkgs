{
  buildPythonPackage,
  setuptools,
  pytestCheckHook,
  flask,
  flask-login,
  flask-wtf,
  wtforms,
  werkzeug,
  requests,
  python,
  pkg-src,
}:
let
  pythonLibDir = "lib/python${python.passthru.pythonVersion}/site-packages";
in
buildPythonPackage rec {
  pname = "chat_ui";
  version = "0.0.0";
  pyproject = true;
  build-system = [ setuptools ];
  src = "${pkg-src}/chat_ui";
  prePatch = ''
    mkdir -p $out/${pythonLibDir}/templates
    cp templates/index.html $out/${pythonLibDir}/templates/index.html
    cp templates/login.html $out/${pythonLibDir}/templates/login.html
  '';
  propagatedBuildInputs = [
    flask
    flask-login
    flask-wtf
    wtforms
    werkzeug
    requests
  ];
  nativeCheckInputs = [ pytestCheckHook ];
  meta = {
    description = "Logged-in chat UI for the host's local Ollama models (anix-llm's).";
    longDescription = ''
      A model dropdown, a Clear button and streamed replies. The conversation
      lives only in the browser tab; the service logs only when runs happen
      and with which model.
    '';
    autoGenUsageCmd = "--help";
  };
}
