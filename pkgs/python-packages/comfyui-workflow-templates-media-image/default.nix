{
  buildPythonPackage,
  fetchPypi,
}:
buildPythonPackage rec {
  pname = "comfyui-workflow-templates-media-image";
  version = "0.3.160";
  format = "wheel";
  src = fetchPypi {
    inherit version format;
    pname = "comfyui_workflow_templates_media_image";
    dist = "py3";
    python = "py3";
    hash = "sha256-1KXFVBxwiPatscfaQfXXwcFKA37aamHNi0t2wlH6qpM=";
  };
  doCheck = false;
  pythonImportsCheck = [ "comfyui_workflow_templates_media_image" ];
  meta.description = "ComfyUI workflow template media assets (image bundle).";
}
