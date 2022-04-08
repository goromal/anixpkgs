{ writeShellScript }:
rec {
    getBasename = writeShellScript "getBasename" ''
        filename=$(basename -- "$1")
        echo "$filename"
    '';
    getExtension = writeShellScript "getExtension" ''
        filename=`${getBasename} "$1"`
        echo "''${filename##*.}"
    '';
    getWithoutExtension = writeShellScript "getWithoutExtension" ''
        filename=`${getBasename} "$1"`
        echo "''${filename%.*}"
    '';
    replaceExtension = writeShellScript "replaceExtension" ''
        fnamefull="$1"
        newExtension="$2"
        woExt=`${getWithoutExtension} "$fnamefull"`
        echo "$woExt.$newExtension"
    '';
}