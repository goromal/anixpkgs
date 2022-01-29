{ writeShellScript }:
rec {
    getExtension = writeShellScript "getExtension" ''
        fnamefull="$1"
        filename=$(basename -- "$fnamefull")
        echo "''${filename##*.}"
    '';
    getWithoutExtension = writeShellScript "getWithoutExtension" ''
        fnamefull="$1"
        filename=$(basename -- "$fnamefull")
        echo "''${filename%.*}"
    '';
    replaceExtension = writeShellScript "replaceExtension" ''
        fnamefull="$1"
        newExtension="$2"
        woExt=`${getWithoutExtension} "$fnamefull"`
        echo "$woExt.$newExtension"
    '';
}