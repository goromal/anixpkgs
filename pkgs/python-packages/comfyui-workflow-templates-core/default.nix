{
  buildPythonPackage,
  fetchPypi,
}:
buildPythonPackage rec {
  pname = "comfyui-workflow-templates-core";
  version = "0.3.367";
  format = "wheel";
  src = fetchPypi {
    inherit version format;
    pname = "comfyui_workflow_templates_core";
    dist = "py3";
    python = "py3";
    hash = "sha256-a6fCW42l3O4kkdPxVu3yTlnT3Wjt+2SQMvaJ8D/cUQE=";
  };
  doCheck = false;
  pythonImportsCheck = [ "comfyui_workflow_templates_core" ];
  meta.description = "Core helpers for ComfyUI workflow templates.";
}
