{
  buildPythonPackage,
  fetchPypi,
  autoPatchelfHook,
  stdenv,
}:
buildPythonPackage rec {
  pname = "comfy-aimdo";
  version = "0.5.5";
  format = "wheel";
  src = fetchPypi {
    inherit version format;
    pname = "comfy_aimdo";
    dist = "cp39";
    python = "cp39";
    abi = "abi3";
    platform =
      if stdenv.hostPlatform.isAarch64 then
        "manylinux2014_aarch64.manylinux_2_17_aarch64"
      else
        "manylinux2014_x86_64.manylinux_2_17_x86_64";
    hash =
      if stdenv.hostPlatform.isAarch64 then
        "sha256-IrZkGfnxiH/Z+0nw5f+aiLeow49rlHKeXC6L+Tb/LXA="
      else
        "sha256-ek3HaDEnOi+Df2fPScnlB+d4sZr/F+bvijSm6WlP2Go=";
  };
  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];
  pythonImportsCheck = [ "comfy_aimdo.control" ];
  meta.description = "Attention implementation for ComfyUI.";
}
