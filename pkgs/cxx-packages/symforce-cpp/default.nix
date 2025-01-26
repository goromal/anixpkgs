{ clangStdenv, cmake, gmp, eigen, catch2, pkg-src }:
clangStdenv.mkDerivation {
  name = "symforce-cpp";
  version = "0.9.0";
  src = pkg-src;
  nativeBuildInputs = [ cmake ];
  buildInputs = [ gmp eigen catch2 ];
  preConfigure = ''
    cmakeFlags="$cmakeFlags --no-warn-unused-cli"
  '';
  meta = {
    description =
      "C++ bindings for the symforce library.";
    longDescription = ''
      [Repository](https://github.com/symforce-org/symforce/tree/main)
    '';
    autoGenUsageCmd = "--help";
  };
}
