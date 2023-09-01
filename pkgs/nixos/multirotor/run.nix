{ writeShellScriptBin, callPackage, pkgs, config, lib }:
let
  cmd-name = "multirotor-sim";
  usage_str = ''
    usage: ${cmd-name}

    Run a SITL emulation for the multirotor sim.
  '';
  argparse = callPackage ../../bash-packages/bash-utils/argparse.nix {
    inherit usage_str;
    optsWithVarsAndDefaults = [ ];
  };
  multirotorSim = import ./multirotor-sim.nix { inherit pkgs config lib; };
in writeShellScriptBin "multirotor-sim" ''
  ${argparse}
  echo "${multirotorSim.driver}"
  sudo ${multirotorSim.driver}/bin/nixos-test-driver
''
