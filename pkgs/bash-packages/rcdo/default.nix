{ callPackage, writeShellScriptBin }:
let
  pkgname = "rcdo";
  usagestr = ''
    ${pkgname} [command]

    Run local [command] on a remote machine via ssh/scp.

    Examples:

    1) One-liner for running remote commands on a remote machine:

      ${pkgname} at:user@hostname ls ~/remote/dir

    2) Run a local conversion tool on a remote video file ("remote input"), storing the result locally:

      ${pkgname} mp4 in:user@hostname:~/video.mov ~/converted_vid.mp4

    3) Run a local conversion tool on a local video file and store the result remotely ("remote output"):

      ${pkgname} mp4 ~/video.mov out:user@hostname:~/converted_vid.mp4
  '';
in (writeShellScriptBin pkgname ''
  echo "TODO"
'') // {
  meta = {
    description = "Run local commands on remote files.";
    longDescription = ''
      ```bash
      ${usagestr}
      ``` 
    '';
  };
}
