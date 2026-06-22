{
  buildPythonPackage,
  fetchPypi,
}:
buildPythonPackage rec {
  pname = "comfyui-workflow-templates-media-api";
  version = "0.3.47";
  format = "wheel";
  src = fetchPypi {
    inherit version format;
    pname = "comfyui_workflow_templates_media_api";
    dist = "py3";
    python = "py3";
    hash = "sha256-D3aZRzP4tbkI3yEh/WZM3H4E6yUmMD2d8i3x5BricRI=";
  };
  doCheck = false;
  pythonImportsCheck = [ "comfyui_workflow_templates_media_api" ];
  meta.description = "ComfyUI workflow template media assets (api bundle).";
}
