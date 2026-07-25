{
  buildPythonPackage,
  fetchPypi,
}:
buildPythonPackage rec {
  pname = "comfyui-workflow-templates-media-video";
  version = "0.3.41";
  format = "wheel";
  src = fetchPypi {
    inherit version format;
    pname = "comfyui_workflow_templates_media_video";
    dist = "py3";
    python = "py3";
    hash = "sha256-NGUMPbb2patwhXJ/apMDLOxksI1z8Iwc0OsIPqYv4/U=";
  };
  doCheck = false;
  pythonImportsCheck = [ "comfyui_workflow_templates_media_video" ];
  meta.description = "ComfyUI workflow template media assets (video bundle).";
}
