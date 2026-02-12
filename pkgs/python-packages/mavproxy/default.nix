{
  stdenv,
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  lxml,
  matplotlib,
  numpy,
  opencv-python,
  pymavlink,
  pyserial,
  setuptools,
  wxpython,
  billiard,
  gnureadline,
}:

buildPythonPackage rec {
  pname = "MAVProxy";
  version = "master";
  format = "setuptools";

  src = builtins.fetchGit {
    url = "https://github.com/ArduPilot/MAVProxy.git";
    ref = "master";
    rev = "4948a269a63288103633ae30c60b861656fbc16b";
  };

  propagatedBuildInputs = [
    lxml
    matplotlib
    numpy
    opencv-python
    pymavlink
    pyserial
    setuptools
    wxpython
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    billiard
    gnureadline
  ];

  # No tests
  doCheck = false;

  meta = with lib; {
    description = "MAVLink proxy and command line ground station";
    homepage = "https://github.com/ArduPilot/MAVProxy";
    license = licenses.gpl3Plus;
  };
}
