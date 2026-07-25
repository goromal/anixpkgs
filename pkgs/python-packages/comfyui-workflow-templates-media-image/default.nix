{
  buildPythonPackage,
  fetchPypi,
}:
buildPythonPackage rec {
  pname = "comfyui-workflow-templates-media-image";
  version = "0.3.73";
  format = "wheel";
  src = fetchPypi {
    inherit version format;
    pname = "comfyui_workflow_templates_media_image";
    dist = "py3";
    python = "py3";
    hash = "sha256-fK78KKCtIZPOYElWGkWHPIi07NFs3sZFFUzuB5LUFPA=";
  };
  doCheck = false;
  pythonImportsCheck = [ "comfyui_workflow_templates_media_image" ];
  meta.description = "ComfyUI workflow template media assets (image bundle).";
}
