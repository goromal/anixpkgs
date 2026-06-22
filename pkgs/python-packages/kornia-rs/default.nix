{
  buildPythonPackage,
  fetchPypi,
  autoPatchelfHook,
  stdenv,
}:
buildPythonPackage rec {
  pname = "kornia-rs";
  version = "0.1.9";
  format = "wheel";
  src = fetchPypi {
    inherit version format;
    pname = "kornia_rs";
    dist = "cp313";
    python = "cp313";
    abi = "cp313";
    platform = "manylinux_2_17_aarch64.manylinux2014_aarch64";
    hash = "sha256-AAIbsZQXZuHp6MLNvrzzOgj43jWG5u/HkblYCn5Ste0=";
  };
  # nixpkgs builds kornia-rs from source and marks it badPlatforms=aarch64-linux
  # (rustc SIGSEGV compiling kornia-3d). kornia 0.8.2 imports kornia_rs eagerly
  # (kornia -> utils.image_print -> io -> kornia_rs), so it cannot be dropped;
  # on the Jetson we install the upstream prebuilt manylinux aarch64 wheel and
  # autoPatchelf its native extension for Nix.
  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];
  pythonImportsCheck = [ "kornia_rs" ];
  meta.description = "Python bindings to the kornia-rs low-level computer vision library (Rust).";
}
