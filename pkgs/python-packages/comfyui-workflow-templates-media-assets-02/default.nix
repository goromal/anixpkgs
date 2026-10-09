{
  buildPythonPackage,
  fetchPypi,
}:
buildPythonPackage rec {
  pname = "comfyui-workflow-templates-media-assets-02";
  version = "0.1.9";
  format = "wheel";
  src = fetchPypi {
    inherit version format;
    pname = "comfyui_workflow_templates_media_assets_02";
    dist = "py3";
    python = "py3";
    hash = "sha256-Zss/wW6rhBB0LWlJVQ32z8cSRXEGXVDhqQEoxJE7Wew=";
  };
  doCheck = false;
  pythonImportsCheck = [ "comfyui_workflow_templates_media_assets_02" ];
  meta.description = "ComfyUI workflow template media assets.";
}
