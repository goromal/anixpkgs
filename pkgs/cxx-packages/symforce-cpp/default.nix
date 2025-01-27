{ lib, clangStdenv, fetchFromGitHub, defaultPython, cmake, gmp, eigen, fmt
, pkg-src }:
let
  symforce-src = pkg-src;
  skymarshal = defaultPython.pkgs.buildPythonPackage rec {
    pname = "skymarshal";
    version = "0.0.0";
    propagatedBuildInputs = with defaultPython.pkgs; [ ply numpy six ];
    src = "${symforce-src}/third_party/skymarshal";
    doCheck = false;
  };
  catch2_v3 = clangStdenv.mkDerivation rec {
    name = "catch2";
    version = "3.5.4";
    src = fetchFromGitHub {
      owner = "catchorg";
      repo = "Catch2";
      rev = "v${version}";
      sha256 = "sha256-3z4/kBEW2zQQJkcdkXhN6NK9+wryXVfEm3MK1wZ3SCE=";
    };
    nativeBuildInputs = [ cmake ];
    cmakeFlags = [ "-H.." ];
  };
  fmt_v8 = clangStdenv.mkDerivation rec {
    name = "fmt";
    version = "8.1.1";
    src = fetchFromGitHub {
      owner = "fmtlib";
      repo = "fmt";
      rev = version;
      sha256 = "sha256-leb2800CwdZMJRWF5b1Y9ocK0jXpOX/nwo95icDf308=";
    };
    nativeBuildInputs = [ cmake ];
    cmakeFlags = [ (lib.cmakeBool "BUILD_SHARED_LIBS" true) ];
    doCheck = false;
  };
  spdlog_v1_10 = let staticBuild = false;
  in clangStdenv.mkDerivation rec {
    name = "spdlog";
    version = "1.10.0";
    src = fetchFromGitHub {
      owner = "gabime";
      repo = "spdlog";
      rev = "v${version}";
      sha256 = "sha256-c6s27lQCXKx6S1FhZ/LiKh14GnXMhZtD1doltU4Avws=";
    };
    nativeBuildInputs = [ cmake ];
    buildInputs = [ catch2_v3 ];
    propagatedBuildInputs = [ fmt_v8 ];
    patches = [ ./spdlog_build.patch ];
    cmakeFlags = [
      "-DSPDLOG_BUILD_SHARED=${if staticBuild then "OFF" else "ON"}"
      "-DSPDLOG_BUILD_STATIC=${if staticBuild then "ON" else "OFF"}"
      "-DSPDLOG_BUILD_EXAMPLE=OFF"
      "-DSPDLOG_BUILD_BENCH=OFF"
      "-DSPDLOG_BUILD_TESTS=ON"
      "-DSPDLOG_FMT_EXTERNAL=ON"
    ];
    doCheck = false;
  };
  tl-optional = clangStdenv.mkDerivation rec {
    name = "optional";
    version = "1.1.0";
    src = fetchFromGitHub {
      owner = "TartanLlama";
      repo = "optional";
      rev = "v${version}";
      sha256 = "sha256-WPTXTQmzJjAIJI1zM6svZZTO8gP/jt5xDHHRCCu9cmI=";
    };
    nativeBuildInputs = [ cmake ];
  };
  pythonWithPkgs =
    defaultPython.withPackages (p: with p; [ argh skymarshal pybind11 ]);
in clangStdenv.mkDerivation {
  name = "symforce-cpp";
  version = "0.9.0";
  src = symforce-src;
  nativeBuildInputs = [ cmake pythonWithPkgs ];
  buildInputs = [ gmp eigen catch2_v3 fmt_v8 spdlog_v1_10 tl-optional ];
  preConfigure = ''
    cmakeFlags="$cmakeFlags --no-warn-unused-cli"
  '';
  meta = {
    description = "C++ bindings for the symforce library.";
    longDescription = ''
      [Repository](https://github.com/symforce-org/symforce/tree/main)
    '';
    autoGenUsageCmd = "--help";
  };
}
