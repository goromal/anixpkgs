{ writeShellScript }: rec {
  getBasename = writeShellScript "getBasename" ''
    filename=$(basename -- "$1")
    echo "$filename"
  '';
  getBaseDir = writeShellScript "getBaseDir" ''
    dname=$(basename -- $(dirname -- $(realpath "$1")))
    echo "$dname"
  '';
  getExtension = writeShellScript "getExtension" ''
    filename=`${getBasename} "$1"`
    echo "''${filename##*.}"
  '';
  getWithoutExtension = writeShellScript "getWithoutExtension" ''
    filename="$1"
    echo "''${filename%.*}"
  '';
  replaceExtension = writeShellScript "replaceExtension" ''
    fnamefull="$1"
    newExtension="$2"
    woExt=`${getWithoutExtension} "$fnamefull"`
    echo "$woExt.$newExtension"
  '';
  escapeSpaces = writeShellScript "escapeSpaces" ''
    line="$1"
    echo "$line" | sed 's/ /\\ /g'
  '';
  dashSpaces = writeShellScript "dashSpaces" ''
    line="$1"
    echo "$line" | sed 's/ /-/g'
  '';
  removeListNotation = writeShellScript "removeListNotation" ''
    line="$1"
    echo "$line" | tr -d '[,],(,)'
  '';
  kebabToSnake = writeShellScript "kebabToSnake" ''
    kebabstr="$1"
    echo "''${kebabstr//-/_}"
  '';
}
