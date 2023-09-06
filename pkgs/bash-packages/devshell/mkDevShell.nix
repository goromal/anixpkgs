{ pkgs ? import <nixpkgs> { }, setupws, wsname, devDir, dataDir, pkgsVar
, repoSpecList, shellSetupScript }:
let
  shellSetupArgs = builtins.concatStringsSep " "
    (map (x: "${x.name}:${x.attr}:${builtins.concatStringsSep ":" x.deps}")
      repoSpecList);
  reposWithUrls =
    builtins.concatStringsSep " " (map (x: "${x.name}:${x.url}") repoSpecList);
  setupcurrentws = pkgs.writeShellScriptBin "setupcurrentws" ''
    mkdir -p ${devDir}/${wsname}
    ${pkgs.python3}/bin/python ${shellSetupScript} ${devDir}/${wsname} '${pkgsVar}' ${shellSetupArgs}
    ${setupws}/bin/setupws --dev_dir ${devDir} --data_dir ${dataDir} ${wsname} ${reposWithUrls}
  '';
in pkgs.mkShell {
  nativeBuildInputs = [ setupcurrentws ];
  shellHook = ''
    export PS1='\n\[\033[1;36m\][devshell=${wsname}:\w]\$\[\033[0m\] '
    alias godev='cd ${devDir}/${wsname}'
    setupcurrentws
    cd ${devDir}/${wsname}
  '';
}
