{
  pkgs ? import <nixpkgs> { },
  pkgList ? [ ], # pkgListStr = "[" + (builtins.concatStringsSep " " pkgList) + "]";
  shellName ? "custom-shell",
  colorCode ? 36,
  hookCmd ? "",
}:
pkgs.mkShell {
  buildInputs = pkgList;
  shellHook = ''
    export PS1='\n\[\033[1;${builtins.toString colorCode}m\][${shellName}:\w]\$\[\033[0m\] '
    ${hookCmd}
  '';
}
