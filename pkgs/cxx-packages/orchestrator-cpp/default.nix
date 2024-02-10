{ clangStdenv, cmake, boost, mscpp, pkg-src }:
clangStdenv.mkDerivation {
  name = "orchestrator-cpp";
  version = "0.0.0";
  src = pkg-src;
  nativeBuildInputs = [ cmake ];
  buildInputs = [ boost mscpp ];
  preConfigure = ''
    cmakeFlags="$cmakeFlags --no-warn-unused-cli"
  '';
  meta = {
    description =
      "C++ implementation of a multi-threaded job manager for my OS.";
    longDescription = ''
      [Repository](https://github.com/goromal/orchestrator-cpp)

      ***Under construction***
    '';
  };
}
