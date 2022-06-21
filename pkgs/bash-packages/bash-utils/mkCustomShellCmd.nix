{ pkgList ? []
, shellName ? "custom-shell"
, hookCmd ? ""
}:
let
    pkgListStr = "[" + (builtins.concatStringsSep " " pkgList) + "]";
in ''
    nix-shell '<nixpkgs/pkgs/bash-packages/bash-utils/customShell.nix>' \
      --arg pkgList "${pkgListStr}" \
      --argstr shellName "${shellName}" \
      --argstr hookCmd "${hookCmd}"
''
