{ writeArgparseScriptBin, color-prints, sshpass, sread }:
let
  pkgname = "local-ssh-proxy";
  printErr = "${color-prints}/bin/echo_red";
in (writeArgparseScriptBin pkgname ''
  usage: ${pkgname} [options] hostname

  SSH proxy function for registered LAN hosts.

  Options:
    -p              Port
  '' [{
    var = "port";
    isBool = false;
    default = "22";
    flags = "-p";
  }] ''
    if [[ -z "$1" ]]; then
      ${printErr} "Please provide a hostname."
      exit 1
    fi
    host="$1"

    name="''${host%.local}"
    ip=$(cat "$HOME/secrets/$name/i.txt")
    password=$(${sread}/bin/sread "$HOME/secrets/$name/p.txt.tyz")
    exec ${sshpass}/bin/sshpass -p "$password" ssh -o StrictHostKeyChecking=no -p "$port" "$USER@$ip"
  '') // {
    meta = {
      description = "SSH proxy function for registered LAN hosts.";
      longDescription = "";
      autoGenUsageCmd = "--help";
    };
  }