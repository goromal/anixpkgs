{
  buildPythonPackage,
  fetchPypi,
  comfyui-workflow-templates-core,
}:
buildPythonPackage rec {
  pname = "comfyui-workflow-templates";
  version = "0.8.24";
  format = "wheel";
  src = fetchPypi {
    inherit version format;
    pname = "comfyui_workflow_templates";
    dist = "py3";
    python = "py3";
    hash = "sha256-y6z8TJc0fFlyEYL5vzUYQkUHbeNo7bruy+qQGlqPhSg=";
  };
  propagatedBuildInputs = [ comfyui-workflow-templates-core ];
  doCheck = false;
  pythonImportsCheck = [ "comfyui_workflow_templates" ];
  meta.description = "ComfyUI workflow templates package.";
}
