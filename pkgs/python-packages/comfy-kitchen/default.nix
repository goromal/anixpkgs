{
  buildPythonPackage,
  fetchPypi,
  torch,
}:
buildPythonPackage rec {
  pname = "comfy-kitchen";
  version = "0.2.10";
  format = "wheel";
  src = fetchPypi {
    inherit version format;
    pname = "comfy_kitchen";
    dist = "py3";
    python = "py3";
    hash = "sha256-wkKv0Y0SDij8lJxCP6KMuyLLTXDWJ9jMfN9rrVTdJyw=";
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
