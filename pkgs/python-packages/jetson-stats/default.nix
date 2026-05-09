{
  buildPythonPackage,
  setuptools,
  pythonRelaxDepsHook,
  packaging,
  smbus2,
  distro,
  nvidia-ml-py,
  pkg-src,
}:
buildPythonPackage rec {
  pname = "jetson-stats";
  version = "7.1.5";
  pyproject = true;
  build-system = [ setuptools ];
  nativeBuildInputs = [ pythonRelaxDepsHook ];
  pythonRelaxDeps = [ "nvidia-ml-py" ];
  src = pkg-src;
  propagatedBuildInputs = [
    packaging
    smbus2
    distro
    nvidia-ml-py
  ];
  doCheck = false;
  meta = {
    description = "Monitor and control your NVIDIA Jetson device.";
    longDescription = ''
      [Repository](https://github.com/rbonghi/jetson_stats)
    '';
    autoGenUsageCmd = "--help";
  };
}
