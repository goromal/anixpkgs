{
  buildPythonPackage,
  setuptools,
  numpy,
  pyyaml,
  pymavlink,
  rosbags,
  pysignals,
  geometry,
  pytestCheckHook,
  pkg-src,
}:
buildPythonPackage rec {
  pname = "indi_harness";
  version = "0.2.0";
  pyproject = true;
  build-system = [ setuptools ];
  propagatedBuildInputs = [
    numpy
    pyyaml
    pymavlink
    rosbags
    pysignals
    geometry
  ];
  nativeCheckInputs = [ pytestCheckHook ];
  src = pkg-src;
  meta = {
    description = "Quaternion INDI control models, rotor-dynamics simulator, and SITL trajectory harness.";
    longDescription = ''
      [Repository](https://github.com/goromal/indi-harness)
    '';
  };
}
