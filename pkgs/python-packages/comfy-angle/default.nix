{
  buildPythonPackage,
  fetchPypi,
  autoPatchelfHook,
  stdenv,
}:
buildPythonPackage rec {
  pname = "comfy-angle";
  version = "0.1.1";
  format = "wheel";
  src = fetchPypi {
    inherit version format;
    pname = "comfy_angle";
    dist = "py3";
    python = "py3";
    platform =
      if stdenv.hostPlatform.isAarch64 then "manylinux_2_28_aarch64" else "manylinux_2_28_x86_64";
    hash =
      if stdenv.hostPlatform.isAarch64 then
        "sha256-ZrfIkJ+YMnk1cDfvD2mU+n4wOkHYp3oKB1pjek6z/m4="
      else
        "sha256-PS/KuThuu7VlPWZpb6i8rTKcHRhS6kth8obqmUhahAo=";
  };
  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];
  pythonImportsCheck = [ "comfy_angle" ];
  meta.description = "Shader support for ComfyUI.";
}
