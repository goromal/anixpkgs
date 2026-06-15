{
  buildPythonPackage,
  setuptools,
  torch,
  torchvision,
  numpy,
  safetensors,
  einops,
  typing-extensions,
  pkg-src,
}:
buildPythonPackage rec {
  pname = "spandrel";
  version = "0.4.2";
  pyproject = true;
  build-system = [ setuptools ];
  src = pkg-src;
  postPatch = ''
    substituteInPlace pyproject.toml --replace 'backend-path = ["."]' ""
  '';
  propagatedBuildInputs = [
    torch
    torchvision
    numpy
    safetensors
    einops
    typing-extensions
  ];
  doCheck = false;
  meta = {
    description = "Neural network model loader for super-resolution and restoration (ComfyUI dep).";
    longDescription = ''
      [Repository](https://github.com/chaiNNer-org/spandrel)
    '';
  };
}
