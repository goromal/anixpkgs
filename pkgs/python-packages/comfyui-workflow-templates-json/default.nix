{
  buildPythonPackage,
  fetchPypi,
}:
buildPythonPackage rec {
  pname = "comfyui-workflow-templates-json";
  version = "0.1.102";
  format = "wheel";
  src = fetchPypi {
    inherit version format;
    pname = "comfyui_workflow_templates_json";
    dist = "py3";
    python = "py3";
    hash = "sha256-fBNh0Ui+h9dOUctR5/Q/3tw63/CoU/RiIXgUM1FANL4=";
  };
  doCheck = false;
  pythonImportsCheck = [ "comfyui_workflow_templates_json" ];
  meta.description = "ComfyUI workflow template JSON files.";
}
