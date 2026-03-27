{
  clangStdenv,
  cmake,
  catch2,
  spdlog,
  grpc,
  protobuf,
  pkg-src,
}:
clangStdenv.mkDerivation {
  name = "mscpp";
  version = "1.0.0";
  src = pkg-src;
  nativeBuildInputs = [ cmake ];
  buildInputs = [
    catch2
    spdlog
  ];
  propagatedBuildInputs = [
    grpc
    protobuf
  ];
  preConfigure = ''
    cmakeFlags="$cmakeFlags --no-warn-unused-cli"
  '';
  meta = {
    description = "Useful template classes for creating multithreaded, interdependent microservices in C++.";
    longDescription = ''
      [Repository](https://github.com/goromal/mscpp)

      **Use cases pending.**
    '';
  };
}
