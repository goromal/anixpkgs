{
  buildPythonPackage,
  fetchPypi,
}:
buildPythonPackage rec {
  pname = "comfyui-frontend-package";
  version = "1.53.10";
  format = "wheel";
  src = fetchPypi {
    inherit version format;
    pname = "comfyui_frontend_package";
    dist = "py3";
    python = "py3";
    hash = "sha256-V1IPBQoYwbM+OhnTeDFWbiux1JYwejC3AbTDvZ7IfcE=";
  };
  doCheck = false;
  pythonImportsCheck = [ "comfyui_frontend_package" ];
  meta.description = "ComfyUI frontend static assets package.";
}
