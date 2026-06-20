{
  clangStdenv,
  cmake,
  asio,
  zlib,
  openssl,
  pkg-src,
}:
clangStdenv.mkDerivation {
  name = "crowcpp";
  version = "1.0.0";
  src = pkg-src;
  postPatch =
    let
      # Asio 1.36 removed the io_service typedef and deprecated free-standing member functions.
      # Migrate all uses to the new API.
      ioServiceFiles = [
        "include/crow/socket_adaptors.h"
        "include/crow/http_connection.h"
        "include/crow/task_timer.h"
        "include/crow/http_server.h"
        "include/crow/http_request.h"
        "tests/unittest.cpp"
      ];
    in
    ''
      for f in ${builtins.toString ioServiceFiles}; do
        substituteInPlace "$f" \
          --replace-warn 'asio::io_service' 'asio::io_context'
      done
      # io_context no longer has .post()/.dispatch() members; use free functions
      substituteInPlace include/crow/http_request.h \
        --replace-warn 'io_service->post(handler)'     'asio::post(*io_service, handler)' \
        --replace-warn 'io_service->dispatch(handler)' 'asio::dispatch(*io_service, handler)'
      substituteInPlace include/crow/http_server.h \
        --replace-warn 'is.post(' 'asio::post(is, '
      # asio::ip::address::from_string removed in Asio 1.22+; use make_address
      substituteInPlace include/crow/http_server.h \
        --replace-warn 'asio::ip::address::from_string(bindaddr)' 'asio::ip::make_address(bindaddr)'
      substituteInPlace tests/unittest.cpp \
        --replace-warn 'asio::ip::address::from_string(' 'asio::ip::make_address('
    '';
  nativeBuildInputs = [ cmake ];
  buildInputs = [
    asio
    zlib
    openssl
  ];
  preConfigure = ''
    cmakeFlags="$cmakeFlags --no-warn-unused-cli"
  '';
  meta = {
    description = "A minimally-patched [fork](https://github.com/goromal/Crow) of [Crow](https://github.com/CrowCpp/Crow), a C++ webserver.";
    longDescription = ''
      The patch allows one to dynamically specify where the website's assets directory is; a necessary feature for [rankserver-cpp](./rankserver-cpp.md).
    '';
  };
}
