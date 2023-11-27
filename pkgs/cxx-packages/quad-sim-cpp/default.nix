{ clangStdenv, cmake, eigen, manif-geom-cpp, signals-cpp, yaml-cpp, boost, pkg-src }:
clangStdenv.mkDerivation {
  name = "quad-sim-cpp";
  version = "0.0.0";
  src = pkg-src;
  nativeBuildInputs = [ cmake ];
  buildInputs = [
    eigen
    manif-geom-cpp
    signals-cpp
    boost
    yaml-cpp
  ];
  preConfigure = ''
    cmakeFlags="$cmakeFlags --no-warn-unused-cli"
  '';
  meta = {
    description = "C++ library and daemon for simulating quadrotor dynamics from PWM motor inputs.";
    longDescription = ''
    [Repository](https://github.com/goromal/quad-sim-cpp)

    ***Under construction.***
    '';
  };
}
