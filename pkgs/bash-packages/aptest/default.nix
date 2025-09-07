{ writeTextFile, mkShell, procps, coreutils, writeArgparseScriptBin
, color-prints, mavproxy, git, python310, stdenv, overrideCC, gcc10 }:
let
  pkgname = "aptest";
  printErr = "${color-prints}/bin/echo_red";
  printYlw = "${color-prints}/bin/echo_yellow";
  apShell = writeTextFile {
    name = "shell.nix";
    text = ''
      { pkgs ? import <nixpkgs> {} }:
      pkgs.mkShell {
        nativeBuildInputs = [
          ${overrideCC stdenv gcc10}
          ${gcc10}
          ${coreutils}
          ${procps}
          ${git}
        ];
        buildInputs = [
          ${mavproxy}
          ${python310}
          ${python310.pkgs.pexpect}
          ${python310.pkgs.setuptools}
          ${python310.pkgs.pymavlink}
          ${python310.pkgs.dronecan}
          ${python310.pkgs.empy}
          ${python310.pkgs.requests}
          ${python310.pkgs.monotonic}
          ${python310.pkgs.geocoder}
          ${python310.pkgs.configparser}
          ${python310.pkgs.click}
          ${python310.pkgs.decorator}
        ];
      }
    '';
  };
in (writeArgparseScriptBin pkgname ''
  usage: ${pkgname} [options] path_to_ardupilot

  Run a SITL instance of ardupilot from source.

  Options:
    -f|--frame     Copter frame to simulate [default: heli]
'' [{
  var = "copter_frame";
  isBool = false;
  default = "heli";
  flags = "-f|--frame";
}] ''
  if [[ -z "$1" ]]; then
    ${printErr} "Must specify the path to ardupilot"
    exit 1
  fi
  appath="$1"
  pushd "$appath"
  appath="$PWD"
  cd $(mktemp -d)
  tmppath="$PWD"

  ${printYlw} "Cloning the ardupilot source"
  cp -r "$appath" "$tmppath/ardupilot"
  cd ardupilot

  ${printYlw} "Patching the source"
  sed -i 's#BINDING_CC="gcc"#BINDING_CC="${gcc10}/bin/gcc"#g' libraries/AP_Scripting/wscript
  sed -i 's/-Werror//g' libraries/AP_Scripting/wscript
  unset shellHook
  nix-shell -p ${stdenv} --run "patchShebangs ./waf && patchShebangs ./Tools"
  ${printYlw} "Running the SITL"
  nix-shell ${apShell} --run "./Tools/autotest/sim_vehicle.py -v ArduCopter -f $copter_frame --map --console"

  ${printYlw} "Cleaning up"
  popd
  rm -rf "$tmppath"
'') // {
  meta = {
    description = "Run a SITL instance of ardupilot from source.";
    longDescription = ''
      ## Sample Commands (for heli)

      - If you're running LUA scripts and have some in an `ardupilot/scripts` directory:
        - `param set SCR_ENABLE 1`
        - `reboot`
      - `param set DISARM_DELAY 0`
      - `mode guided`
      - `arm throttle`
      - `takeoff 25`
    '';
    autoGenUsageCmd = "--help";
  };
}
