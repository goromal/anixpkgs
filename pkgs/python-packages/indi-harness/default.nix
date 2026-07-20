{
  buildPythonPackage,
  setuptools,
  numpy,
  pyyaml,
  pymavlink,
  rosbags,
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
  ];
  nativeCheckInputs = [ pytestCheckHook ];
  src = pkg-src;
  meta = {
    description = "Quaternion INDI prototype and SITL trajectory harness (S0/S1 of the ArduPilot INDI plan).";
    longDescription = ''
      [Repository](https://github.com/goromal/indi-harness)
    '';
  };
}
