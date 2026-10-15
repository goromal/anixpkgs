{
  buildPythonPackage,
  fetchPypi,
}:
buildPythonPackage rec {
  pname = "comfyui-workflow-templates-media-video";
  version = "0.3.101";
  format = "wheel";
  src = fetchPypi {
    inherit version format;
    pname = "comfyui_workflow_templates_media_video";
    dist = "py3";
    python = "py3";
    hash = "sha256-YnD9YcjDkxtvADGrrH1MkM7WJN5seRi/+FuJ5sPXSTw=";
  };
  doCheck = false;
  pythonImportsCheck = [ "comfyui_workflow_templates_media_video" ];
  meta.description = "ComfyUI workflow template media assets (video bundle).";
}
