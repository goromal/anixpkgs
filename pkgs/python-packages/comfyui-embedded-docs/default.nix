{
  buildPythonPackage,
  fetchPypi,
}:
buildPythonPackage rec {
  pname = "comfyui-embedded-docs";
  version = "0.5.13";
  format = "wheel";
  src = fetchPypi {
    inherit version format;
    pname = "comfyui_embedded_docs";
    dist = "py3";
    python = "py3";
    hash = "sha256-ENi+ho87tk7fC2I47C8JZ60rbT9eCMlw+VGA0cDDRpA=";
  };
  doCheck = false;
  pythonImportsCheck = [ "comfyui_embedded_docs" ];
  meta.description = "ComfyUI embedded documentation package.";
}
