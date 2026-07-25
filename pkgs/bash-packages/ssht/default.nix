{
  writeShellScriptBin,
  openssh,
  color-prints,
}:
let
  pkgname = "ssht";
  printErr = "${color-prints}/bin/echo_red";
in
(writeShellScriptBin pkgname ''
  session="work"
  forwards=()
  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help)
        cat << EOF
  usage: ${pkgname} [-u] [-L <spec>] [-s <session>] <host>

  SSH to a host and attach/create a remote tmux session.
  The remote session starts with HISTSIZE=999 exported so command history
  survives through the session.

  Flags:
    -u            Forward local 8080 to remote 443 (the Lattice UI).
    -L <spec>     Extra -L forward spec (repeatable). E.g. -L 9090:localhost:9090
    -s <session>  Remote tmux session name (default: "work").
  EOF
        exit 0
        ;;
      -u) forwards+=("-L" "8080:127.0.0.1:443"); shift ;;
      -L) forwards+=("-L" "$2"); shift 2 ;;
      -s) session="$2"; shift 2 ;;
      --) shift; break ;;
      -*) ${printErr} "${pkgname}: unknown flag $1"; exit 1 ;;
      *)  break ;;
    esac
  done

  if [ -z "$1" ]; then
    ${printErr} "usage: ${pkgname} [-u] [-L spec] [-s session] <host>"
    exit 1
  fi
  host="$1"

  exec ${openssh}/bin/ssh -t "''${forwards[@]}" "$host" \
    "export HISTSIZE=999; tmux new -As $session"
'')
// {
  meta = {
    description = "SSH to a host and attach/create a remote tmux session.";
    longDescription = ''
      Wraps `ssh` with optional port-forwarding and an automatic `tmux new -As <session>`
      on the remote, with `HISTSIZE=999` exported so the session retains a useful command
      history.
    '';
    autoGenUsageCmd = "--help";
  };
}
