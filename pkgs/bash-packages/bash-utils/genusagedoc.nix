{
  runCommand,
  packageAttr,
  helpCmd ? "--help",
  subCmds ? [ ],
}:
let
  mkSubCmds = builtins.concatStringsSep "\n" (
    map (x: ''
      echo -e "\n\n### ${x}" >> $out
      echo -e "\n\n\`\`\`bash" >> $out
      "$xc" ${x} ${helpCmd} >> $out || true
      echo -n "\`\`\`" >> $out
    '') subCmds
  );
in
runCommand "usage-doc" { } ''
  for xc in "${packageAttr}/bin"/*; do
    echo "\`\`\`bash" >> $out
    "$xc" ${helpCmd} >> $out || true
    echo -n "\`\`\`" >> $out
    ${mkSubCmds}
  done
''
