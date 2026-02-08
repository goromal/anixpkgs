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
  version = "1.8.66";
  format = "setuptools";

  src = fetchFromGitHub {
    owner = "ArduPilot";
    repo = "MAVProxy";
    tag = "v${version}";
    hash = "sha256-vEb5y4hvRjZSRJ6I4S8tC7yAqM2XTvBBQxdz1uOCalQ=";
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
