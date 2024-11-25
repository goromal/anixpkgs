{ pkgs ? import <nixpkgs> { }, printErr, setupws, wsname, devDir, dataDir
, pkgsVar, devrcFile, devScript, parseScript, editorName, shellSetupScript
, devHistFile }:
let
  setupcurrentws = pkgs.writeShellScriptBin "setupcurrentws" ''
    mkdir -p ${devDir}/${wsname}
    rcinfo=$(${pkgs.python3}/bin/python ${parseScript} PARSE ${devrcFile} ${wsname})
    if [[ "$rcinfo" == "_NODEVRC_" ]]; then
        ${printErr} "ERROR: no $devrc file found"
        exit 1
    elif [[ "$rcinfo" == "_NOWSGIVEN_" ]]; then
        ${printErr} "ERROR: no workspace name provided."
        exit 1
    elif [[ "$rcinfo" == ERROR* ]]; then
        ${printErr} "''${rcinfo}"
        exit 1
    elif [[ "$rcinfo" == "_NOWSFOUND_" ]]; then
        ${printErr} "ERROR: workspace $wsname not found in $devrc"
        exit 1
    else
        IFS='|' read -ra rcinfoarray <<< "$rcinfo"
        rpspecs_list="''${rcinfoarray[3]}"
        sources_list="''${rcinfoarray[4]}"
        scripts_list="''${rcinfoarray[5]}"
        ${pkgs.python3}/bin/python ${shellSetupScript} ${devDir}/${wsname} '${pkgsVar}' $rpspecs_list
        ${setupws}/bin/setupws --dev_dir ${devDir} --data_dir ${dataDir} ${wsname} $sources_list $scripts_list
    fi
  '';
  dev = pkgs.writeShellScriptBin "dev" ''
    ${pkgs.python3}/bin/python ${devScript} ${wsname} ${devDir}/${wsname} ${editorName} ${devHistFile}
  '';
  addsrc = pkgs.writeShellScriptBin "addsrc" ''
    if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
      echo "addsrc REPONAME [REPOURL]"
      exit
    fi
    if [[ -z "$1" ]]; then
      echo "addsrc REPONAME [REPOURL]"
      exit
    fi
    ${pkgs.python3}/bin/python ${parseScript} ADDSRC ${wsname} ${devrcFile} "$1" "$2" && setupcurrentws
  '';
  addscr = pkgs.writeShellScriptBin "addscr" ''
    if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
      echo "addscr SCRIPTNAME [SCRIPTPATH]"
      exit
    fi
    if [[ -z "$1" ]]; then
      echo "addsrc SCRIPTNAME [SCRIPTPATH]"
      exit
    fi
    ${pkgs.python3}/bin/python ${parseScript} ADDSCR ${wsname} ${devrcFile} "$1" "$2" && setupcurrentws
  '';
in pkgs.mkShell {
  nativeBuildInputs = [ setupcurrentws dev addsrc addscr ];
  shellHook = ''
    export PS1='\n\[\033[1;36m\][devshell=${wsname}:\w]\$\[\033[0m\] '
    alias godev='cd ${devDir}/${wsname}'
    setupcurrentws
    cd ${devDir}/${wsname}
  '';
}
