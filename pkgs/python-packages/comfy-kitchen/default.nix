{
  buildPythonPackage,
  fetchPypi,
  torch,
}:
buildPythonPackage rec {
  pname = "comfy-kitchen";
  version = "0.2.37";
  format = "wheel";
  src = fetchPypi {
    inherit version format;
    pname = "comfy_kitchen";
    dist = "py3";
    python = "py3";
    hash = "sha256-tia9Uf9Fk38URqzPB4zOqdEcNob/oMibDBMF1m12Wv4=";
  };
  propagatedBuildInputs = [ torch ];
  # Pure-Python wheel: torch propagates ninja/cmake build hooks that would
  # otherwise trigger a spurious (and failing) native buildPhase.
  dontBuild = true;
  dontUseNinjaBuild = true;
  dontUseCmakeConfigure = true;
  doCheck = false;
  pythonImportsCheck = [ "comfy_kitchen" ];
  meta.description = "Fast kernel library for ComfyUI — fp8/fp4 quantized tensor ops.";
}
