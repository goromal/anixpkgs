{
  buildPythonPackage,
  fetchPypi,
}:
buildPythonPackage rec {
  pname = "comfyui-workflow-templates-core";
  version = "0.3.112";
  format = "wheel";
  src = fetchPypi {
    inherit version format;
    pname = "comfyui_workflow_templates_core";
    dist = "py3";
    python = "py3";
    hash = "sha256-jKOeIhb6aN5ehHq0r8mpWFISqrTg8CRuXurHl3bdKhE=";
  };
  doCheck = false;
  pythonImportsCheck = [ "comfyui_workflow_templates_core" ];
  meta.description = "Core helpers for ComfyUI workflow templates.";
}
