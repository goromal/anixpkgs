# ssht

SSH to a host and attach/create a remote tmux session.

Wraps `ssh` with optional port-forwarding and an automatic `tmux new -As <session>`
on the remote, with `HISTSIZE=999` exported so the session retains a useful command
history.

## Usage

```bash
usage: ssht [-u] [-L <spec>] [-s <session>] <host>

SSH to a host and attach/create a remote tmux session.
The remote session starts with HISTSIZE=999 exported so command history
survives through the session.

Flags:
  -u            Forward local 8080 to remote 443 (the Lattice UI).
  -L <spec>     Extra -L forward spec (repeatable). E.g. -L 9090:localhost:9090
  -s <session>  Remote tmux session name (default: "work").
```

