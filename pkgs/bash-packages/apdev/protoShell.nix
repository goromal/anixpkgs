{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    (overrideCC stdenv gcc10)
    gcc10
    coreutils
    procps
    git
  ];
  buildInputs = with pkgs; with python39.pkgs; [
    python39
    pexpect
    setuptools
    pymavlink
    dronecan
    empy
    requests
    monotonic
    geocoder
    configparser
    click
    decorator
  ];
  shellHook = ''
    alias sitl='./Tools/autotest/sim_vehicle.py -v ArduCopter -f heli --map --console'
  '';
}