{ pkgs ? import <nixpkgs> {}
, pkgList ? []
, shellName ? "custom-shell"
, hookCmd ? ""
}:
pkgs.mkShell {
    buildInputs = pkgList;
    shellHook = ''
        export PS1='\n\[\033[1;36m\][${shellName}:\w]\$\[\033[0m\] '
        ${hookCmd}
    '';
}
