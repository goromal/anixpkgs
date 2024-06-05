{ runCommand, coreutils, packageAttr, helpCmd ? "--help" }:
let
  cmdOutputFile = ((runCommand "mh" { } ''
    mkdir $out
    for xc in "${packageAttr}/bin"/*; do
      "$xc" ${helpCmd} > $out/helpstr.txt
    done  
  '') + "/helpstr.txt");
in builtins.readFile cmdOutputFile
