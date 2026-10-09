{
  buildPythonPackage,
  fetchPypi,
  comfyui-workflow-templates-core,
  comfyui-workflow-templates-json,
  comfyui-workflow-templates-media-assets-01,
  comfyui-workflow-templates-media-assets-02,
  comfyui-workflow-templates-media-api,
  comfyui-workflow-templates-media-video,
  comfyui-workflow-templates-media-image,
  comfyui-workflow-templates-media-other,
}:
buildPythonPackage rec {
  pname = "comfyui-workflow-templates";
  version = "0.11.76";
  format = "wheel";
  src = fetchPypi {
    inherit version format;
    pname = "comfyui_workflow_templates";
    dist = "py3";
    python = "py3";
    hash = "sha256-/LQDWUYdKQ9ADdiC+m1D1yX1aQfYKJd38QpmTzf0rAU=";
  };
  propagatedBuildInputs = [
    comfyui-workflow-templates-core
    comfyui-workflow-templates-json
    comfyui-workflow-templates-media-assets-01
    comfyui-workflow-templates-media-assets-02
    comfyui-workflow-templates-media-api
    comfyui-workflow-templates-media-video
    comfyui-workflow-templates-media-image
    comfyui-workflow-templates-media-other
  ];
  doCheck = false;
  pythonImportsCheck = [ "comfyui_workflow_templates" ];
  meta.description = "ComfyUI workflow templates package.";
}
