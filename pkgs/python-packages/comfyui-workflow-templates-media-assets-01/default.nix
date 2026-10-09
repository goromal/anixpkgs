{
  buildPythonPackage,
  fetchPypi,
}:
buildPythonPackage rec {
  pname = "comfyui-workflow-templates-media-assets-01";
  version = "0.1.48";
  format = "wheel";
  src = fetchPypi {
    inherit version format;
    pname = "comfyui_workflow_templates_media_assets_01";
    dist = "py3";
    python = "py3";
    hash = "sha256-dzPtEoZ+lea4s5viC8xzV5wo6X5aRAhv+5d8wsHHjEM=";
  };
  doCheck = false;
  pythonImportsCheck = [ "comfyui_workflow_templates_media_assets_01" ];
  meta.description = "ComfyUI workflow template media assets.";
}
