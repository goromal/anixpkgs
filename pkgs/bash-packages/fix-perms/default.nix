{ writeArgparseScriptBin, color-prints }:
let
  pkgname = "fix-perms";
  printErr = "${color-prints}/bin/echo_red";
  printYlw = "${color-prints}/bin/echo_yellow";
  printGrn = "${color-prints}/bin/echo_green";
in
(writeArgparseScriptBin pkgname
  ''
    usage: ${pkgname} dir

    Recursively claim ownership of all files and folders in dir. Attempts to deduce special cases such as ~/.ssh/*.

    EXAMPLES:

    Current directory is ~/.ssh:

      find . -type d -exec chmod 700 {} \;
      find . -type f -exec chmod 600 {} \;
      find . -type f -name \*.pub -exec chmod 644 {} \;

    Current directory is a normal directory:

      find . -type d -exec chmod 755 {} \;
      find . -type f -exec chmod 644 {} \;
  ''
  [ ]
  ''
    if [[ -z "$1" ]]; then
        ${printErr} "No dir provided."
        exit 1
    fi
    if [[ "$(readlink -f $1)" == *.ssh* ]]; then
        ${printYlw} "Deducing SSH perms rules."
        find "$1" -type d -exec chmod 700 {} \;
        find "$1" -type f -exec chmod 600 {} \;
        find "$1" -type f -name \*.pub -exec chmod 644 {} \;
    else
        ${printYlw} "Applying standard file + dir perms."
        find "$1" -type d -exec chmod 755 {} \; 
        find "$1" -type f -exec chmod 644 {} \;
    fi
    ${printGrn} "Done!"
  ''
)
// {
  meta = {
    description = "Recursively claim ownership of all files and folders in dir.";
    longDescription = "";
    autoGenUsageCmd = "--help";
  };
}
