{
  clangStdenv,
  cmake,
  boost,
  mscpp,
  aapis-cpp,
  protobuf,
  grpc,
  sqlite,
  spdlog,
  catch2,
  pkg-config,
  pkg-src,
}:
clangStdenv.mkDerivation {
  name = "orchestrator-cpp";
  version = "0.0.0";
  src = pkg-src;
  nativeBuildInputs = [ cmake pkg-config ];
  buildInputs = [
    boost
    mscpp
    aapis-cpp
    protobuf
    grpc
    sqlite
    spdlog
    catch2
  ];
  preConfigure = ''
    cmakeFlags="$cmakeFlags --no-warn-unused-cli"
  '';
  cmakeFlags = [
    "-DBUILD_TESTS=OFF"
  ];
  postInstall = ''
    # Rename daemon binary to avoid conflict with Python orchestrator package
    mv $out/bin/orchestratord $out/bin/orchestratord-cpp
    # Client binary orchestratorctl is already uniquely named
  '';
  meta = {
    description = "C++ implementation of a multi-threaded job manager for my OS.";
    longDescription = ''
      [Repository](https://github.com/goromal/orchestrator-cpp)

      A performant C++ implementation of the orchestrator daemon, providing
      job scheduling and execution capabilities via gRPC API.

      Binaries:
      - orchestratord-cpp: The daemon (renamed to avoid conflicts with Python orchestrator)
      - orchestratorctl: CLI client for controlling the daemon
    '';
  };
}
