{ writeArgparseScriptBin, color-prints, git, python39, stdenv, overrideCC, gcc10 }:
let
  pkgname = "apdev";
  printErr = "${color-prints}/bin/echo_red";
  printGrn = "${color-prints}/bin/echo_green";
in (writeArgparseScriptBin pkgname ''
  usage: ${pkgname} path_to_ardupilot

  Drop into a shell + temporary directory where you can run Ardupilot SITLs and build locally.
'' [] ''
  # ^^^^ TODO
'') // {
  meta = {
    description =
      "Make it easier to develop locally on autopilot.";
    longDescription = "";
    autoGenUsageCmd = "--help";
  };
}
