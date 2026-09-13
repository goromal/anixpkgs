# Small-flight regression, not the S4 DDS trajectory acceptance gate.
# Always uses this checkout's remote lock pins, independent of local-build.
# nix-build pkgs/nixos/sitl-envs/indi-actuator-probe.nix -A flight
let
  pkgs = import ../../../default.nix { };
  firmware = pkgs.arducopter.sitl;
  python = pkgs.python313.withPackages (ps: [ ps.indi-harness ]);
in
rec {
  math = firmware.overrideAttrs (old: {
    name = "indi-controller-math-${old.version}";
    configurePhase = ''
      ./waf configure --board linux --enable-custom-controller --no-submodule-update
    '';
    buildPhase = ''
      ./waf build --target tests/test_indi_math -j$NIX_BUILD_CORES
    '';
    installPhase = ''
      mkdir -p $out
      build/linux/tests/test_indi_math --gtest_output=xml:$out/results.xml
      # A build with custom control disabled silently runs zero tests.
      grep -Eq 'tests="([2-9][0-9]|[1-9][0-9]{2,})"' $out/results.xml
    '';
  });
  flight = pkgs.runCommand "indi-actuator-probe" {
    nativeBuildInputs = [ python ];
    # Include the host test in the build graph as well as the DDS SITL package.
    controllerMath = math;
  } ''
    python -m indi_harness.sitl.rate_probe \
      --binary ${firmware}/bin/arducopter \
      --defaults ${firmware.src}/Tools/autotest/default_params/copter.parm \
      --out "$TMPDIR/flight"
    python -m indi_harness.sitl.probe_score "$TMPDIR/flight"
    mkdir -p $out
    cp -r "$TMPDIR/flight/." $out/
  '';
}
