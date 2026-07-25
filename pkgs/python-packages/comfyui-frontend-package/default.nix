{
  buildPythonPackage,
  fetchPypi,
}:
buildPythonPackage rec {
  pname = "comfyui-frontend-package";
  version = "1.37.11";
  format = "wheel";
  src = fetchPypi {
    inherit version format;
    pname = "comfyui_frontend_package";
    dist = "py3";
    python = "py3";
    hash = "sha256-b+0TnslCsFQwVZ+o5FtYQCmz7WI4mSEuxv+1sJzcBCw=";
  };
  doCheck = false;
  pythonImportsCheck = [ "comfyui_frontend_package" ];
  meta.description = "ComfyUI frontend static assets package.";
}
