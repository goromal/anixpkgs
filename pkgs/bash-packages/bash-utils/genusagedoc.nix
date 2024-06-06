{ runCommand, coreutils, packageAttr, helpCmd ? "--help", subCmds ? [] }:
let
  mkSubCmds = builtins.concatStringsSep "\n" (
    map (x: ''echo -e "\n\n" >> $out/helpstr.txt
    "$xc" ${x} ${helpCmd} >> $out/helpstr.txt'') subCmds
  );
  cmdOutputFile = ((runCommand "mh" { } ''
    mkdir $out
    for xc in "${packageAttr}/bin"/*; do
      "$xc" ${helpCmd} >> $out/helpstr.txt
      ${mkSubCmds}
    done  
  '') + "/helpstr.txt");
in builtins.readFile cmdOutputFile
