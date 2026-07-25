{
  lib,
  stdenv,
  cmake,
  fetchFromGitHub,
  fastrtps,
  fastcdr,
  pkg-src,
}:
let
  # The agent's logger profile requires spdlog <= 1.9; newer spdlog/fmt from
  # nixpkgs reject the agent's log statements.
  spdlog_1_9 = stdenv.mkDerivation {
    pname = "spdlog";
    version = "1.9.2";
    src = fetchFromGitHub {
      owner = "gabime";
      repo = "spdlog";
      rev = "v1.9.2";
      hash = "sha256-GSUdHtvV/97RyDKy8i+ticnSlQCubGGWHg4Oo+YAr8Y=";
    };
    nativeBuildInputs = [ cmake ];
    cmakeFlags = [
      "-DSPDLOG_BUILD_EXAMPLE=OFF"
      "-DSPDLOG_BUILD_TESTS=OFF"
      # spdlog's pkg-config template breaks with nixpkgs' absolute libdir
      "-DCMAKE_INSTALL_LIBDIR=lib"
      "-DCMAKE_INSTALL_INCLUDEDIR=include"
    ];
  };
in
stdenv.mkDerivation {
  pname = "microxrcedds-agent";
  version = "2.4.3";

  src = pkg-src;

  nativeBuildInputs = [ cmake ];

  # fastrtps/fastcdr must come from the same nix-ros-overlay package set that
  # provides the ROS2 environment, so the agent speaks the same RTPS wire
  # version as the rmw used by ROS2 nodes.
  buildInputs = [
    fastrtps
    fastcdr
    spdlog_1_9
  ];

  cmakeFlags = [
    "-DUAGENT_SUPERBUILD=OFF"
    "-DUAGENT_USE_SYSTEM_FASTDDS=ON"
    "-DUAGENT_USE_SYSTEM_FASTCDR=ON"
    "-DUAGENT_USE_SYSTEM_LOGGER=ON"
    "-DUAGENT_BUILD_TESTS=OFF"
    "-DUAGENT_P2P_PROFILE=OFF"
  ];

  meta = {
    description = "eProsima Micro XRCE-DDS Agent (bridges XRCE clients like Ardupilot AP_DDS into a DDS/ROS2 graph)";
    mainProgram = "MicroXRCEAgent";
    homepage = "https://github.com/eProsima/Micro-XRCE-DDS-Agent";
    license = lib.licenses.asl20;
  };
}
