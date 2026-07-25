{
  buildPythonPackage,
  fetchPypi,
  setuptools,
  torch,
  torchvision,
  numpy,
}:
buildPythonPackage rec {
  pname = "segment-anything";
  version = "1.0";
  pyproject = true;
  build-system = [ setuptools ];
  src = fetchPypi {
    pname = "segment_anything";
    inherit version;
    hash = "sha256-7Qyfb7B7vvnGI4pwKKE8gnLxumtjBcpz4+BkJmUDc2s=";
  };
  propagatedBuildInputs = [
    torch
    torchvision
    numpy
  ];
  doCheck = false;
  pythonImportsCheck = [ "segment_anything" ];
  meta.description = "Segment Anything (SAM) — ComfyUI Impact Pack dep.";
}
