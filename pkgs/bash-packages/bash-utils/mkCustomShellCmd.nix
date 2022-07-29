{ pkgList ? []
, shellName ? "custom-shell"
, hookCmd ? ""
, runCmd ? ""
}:
let
    pkgListStr = "[" + (builtins.concatStringsSep " " pkgList) + "]";
    runCmdStr = if runCmd != "" then ''--run "${runCmd}"'' else "";
in ''
    nix-shell '<nixpkgs/pkgs/bash-packages/bash-utils/customShell.nix>' \
      --arg pkgList "${pkgListStr}" \
      --argstr shellName "${shellName}" \
      --argstr hookCmd "${hookCmd}" \
      ${runCmdStr}
''
