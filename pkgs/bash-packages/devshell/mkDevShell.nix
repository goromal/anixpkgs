{ pkgs ? import <nixpkgs> {}
, setupws
, wsname
, devDir
, dataDir
, repoSpecList
}:
let
    reposWithUrls = builtins.concatStringsSep " " (map (x: "${x.name}:${x.url}") repoSpecList);
    setupcurrentws = pkgs.writeShellScriptBin "setupcurrentws" ''
        ${setupws}/bin/setupws --dev_dir ${devDir} --data_dir ${dataDir} ${wsname} ${reposWithUrls}
    '';
in pkgs.mkShell {
    nativeBuildInputs = [ setupcurrentws ]; # TODO ^^^^ add smart construction of custom shell using x.deps
    shellHook = ''
        export PS1='\n\[\033[1;36m\][devshell=${wsname}:\w]\$\[\033[0m\] '
        alias godev='cd ${devDir}/${wsname}'
    '';
}
