{ clangStdenv, cmake, asio, zlib, openssl, pkg-src }:
clangStdenv.mkDerivation {
  name = "crowcpp";
  version = "1.0.0";
  src = pkg-src;
  nativeBuildInputs = [ cmake ];
  buildInputs = [ asio zlib openssl ];
  preConfigure = ''
    cmakeFlags="$cmakeFlags --no-warn-unused-cli"
  '';
  meta = {
    description =
      "A minimally-patched [fork](https://github.com/goromal/Crow) of [Crow](https://github.com/CrowCpp/Crow), a C++ webserver.";
    longDescription = ''
      The patch allows one to dynamically specify where the website's assets directory is; a necessary feature for [rankserver-cpp](./rankserver-cpp.md).
    '';
  };
}
