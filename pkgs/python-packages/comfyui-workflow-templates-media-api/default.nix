{
  buildPythonPackage,
  fetchPypi,
}:
buildPythonPackage rec {
  pname = "comfyui-workflow-templates-media-api";
  version = "0.3.84";
  format = "wheel";
  src = fetchPypi {
    inherit version format;
    pname = "comfyui_workflow_templates_media_api";
    dist = "py3";
    python = "py3";
    hash = "sha256-wtalmZrDnk839HriMcklV97+Wt2yzGq1wRQQtNWikQo=";
  };
  doCheck = false;
  pythonImportsCheck = [ "comfyui_workflow_templates_media_api" ];
  meta.description = "ComfyUI workflow template media assets (api bundle).";
}
