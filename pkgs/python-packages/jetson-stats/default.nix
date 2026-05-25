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
  postPatch = ''
        python3 -c "
    import pathlib
    p = pathlib.Path('jtop/core/config.py')
    t = p.read_text()
    p.write_text(t.replace(
        'def get_config_service(data_folder=JTOP_DATA_FOLDER):\n    path = sys.prefix',
        'def get_config_service(data_folder=JTOP_DATA_FOLDER):\n    if os.environ.get(\"JTOP_SERVICE\"):\n        return \"/var/lib/jtop\"\n    path = sys.prefix'
    ))
    p = pathlib.Path('jtop/core/jetson_libraries.py')
    t = p.read_text()
    p.write_text(t.replace(
        'subprocess.call([\"which\", \"nvcc\"], stdout=subprocess.DEVNULL)',
        'subprocess.call([\"which\", \"nvcc\"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)'
    ))
    "
  '';
  doCheck = false;
  meta = {
    description = "Monitor and control your NVIDIA Jetson device.";
    longDescription = ''
      [Repository](https://github.com/rbonghi/jetson_stats)
    '';
    autoGenUsageCmd = "--help";
  };
}
