{ clangStdenv, cmake, eigen, manif-geom-cpp, signals-cpp, catch2, pkg-src }:
clangStdenv.mkDerivation {
  name = "gnc";
  version = "0.0.0";
  src = pkg-src;
  nativeBuildInputs = [ cmake ];
  buildInputs = [ eigen manif-geom-cpp signals-cpp catch2 ];
  preConfigure = ''
    cmakeFlags="$cmakeFlags --no-warn-unused-cli"
  '';
  meta = {
    description =
      "A collection of GNC algorithms, particularly for controlling small UAVs.";
    longDescription = ''
      [Repository](https://github.com/goromal/gnc)

      Examples documented in the [unit tests](https://github.com/goromal/gnc/tree/master/tests).
    '';
  };
}
