{ runCommand, coreutils, packageAttr, helpCmd ? "--help", subCmds ? [ ] }:
let
  mkSubCmds = builtins.concatStringsSep "\n" (map (x: ''
    echo -e "\n\n### ${x}" >> $out/helpstr.txt
    echo -e "\n\n\`\`\`bash" >> $out/helpstr.txt
    "$xc" ${x} ${helpCmd} >> $out/helpstr.txt
    echo -n "\`\`\`" >> $out/helpstr.txt
  '') subCmds);
  cmdOutputFile = ((runCommand "mh" { } ''
    mkdir $out
    for xc in "${packageAttr}/bin"/*; do
      echo "\`\`\`bash" >> $out/helpstr.txt
      "$xc" ${helpCmd} >> $out/helpstr.txt
      echo -n "\`\`\`" >> $out/helpstr.txt
      ${mkSubCmds}
    done  
  '') + "/helpstr.txt");
in builtins.readFile cmdOutputFile
