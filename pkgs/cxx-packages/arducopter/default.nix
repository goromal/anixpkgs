{
  callPackage,
  meson,
  ninja,
  systemd,
  git,
  python,
  stdenv,
  overrideCC,
  pkg-config,
  gcc13,
  gcc-arm-embedded-13,
  flakeInputs,
}:
let
  arduSitlEnv = overrideCC stdenv gcc13;
  arduEmbdEnv = overrideCC stdenv gcc-arm-embedded-13;
  pythonWithPkgs = python.withPackages (ps: [
    ps.empy
    ps.pexpect
    ps.setuptools
  ]);
  mkArduCopter =
    {
      arduEnv,
      board,
      installPhase,
    }:
    arduEnv.mkDerivation rec {
      name = "arducopter-${flakeInputs.ardupilot.shortRev}-${board}";
      version = flakeInputs.ardupilot.shortRev;
      src = flakeInputs.ardupilot;
      inherit board;
      nativeBuildInputs = [
        git
        pythonWithPkgs
      ];
      patchPhase = ''
        git init
        git add modules/ChibiOS modules/mavlink modules/gtest modules/littlefs
        echo ${flakeInputs.ardupilot.rev} > .git/HEAD
        patchShebangs ./waf
        sed -i 's#BINDING_CC="gcc"#BINDING_CC="${gcc13}/bin/gcc"#g' libraries/AP_Scripting/wscript
        sed -i 's/-Werror//g' libraries/AP_Scripting/wscript
        sed -i '1s/^/#include <cstdint>\n/' libraries/AP_HAL_SITL/CANSocketIface.cpp
      '';
      configurePhase = ''
        ./waf configure --board ${board}
        ./waf clean
      '';
      buildPhase = ''
        ./waf copter
      '';
      inherit installPhase;
    };
in
rec {
  router = stdenv.mkDerivation rec {
    pname = "mavlink-router";
    version = "0.0.1";
    src = flakeInputs.mavlink-router;
    nativeBuildInputs = [
      pkg-config
      meson
      ninja
      systemd
    ];
    prePatch = ''
      cp -r ${flakeInputs.mavlink}/* modules/mavlink_c_library_v2/.
    '';
    mesonFlags = [
      "--buildtype=release"
      "-Dsystemdsystemunitdir=daemon"
    ];
  };
  copter = {
    sitl = mkArduCopter {
      arduEnv = arduSitlEnv;
      board = "sitl";
      installPhase = ''
        mkdir -p $out/bin
        mv ./build/sitl/bin/* $out/bin/arducopter
      '';
    };
  };
}
