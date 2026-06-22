{
  buildPythonPackage,
  fetchPypi,
}:
buildPythonPackage rec {
  pname = "comfyui-embedded-docs";
  version = "0.4.0";
  format = "wheel";
  src = fetchPypi {
    inherit version format;
    pname = "comfyui_embedded_docs";
    dist = "py3";
    python = "py3";
    hash = "sha256-l8T4zcrOHpSnVBKMTvU+3ODj3wMI354MmYCA68Slv7I=";
  };
  doCheck = false;
  pythonImportsCheck = [ "comfyui_embedded_docs" ];
  meta.description = "ComfyUI embedded documentation package.";
}
