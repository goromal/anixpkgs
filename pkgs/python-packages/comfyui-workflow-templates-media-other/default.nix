{
  buildPythonPackage,
  fetchPypi,
}:
buildPythonPackage rec {
  pname = "comfyui-workflow-templates-media-other";
  version = "0.3.95";
  format = "wheel";
  src = fetchPypi {
    inherit version format;
    pname = "comfyui_workflow_templates_media_other";
    dist = "py3";
    python = "py3";
    hash = "sha256-Fi0OZnnUlIo0ebnnHN7XrjkenEYGSb5BdrZik9Ey6CY=";
  };
  doCheck = false;
  pythonImportsCheck = [ "comfyui_workflow_templates_media_other" ];
  meta.description = "ComfyUI workflow template media assets (other bundle).";
}
