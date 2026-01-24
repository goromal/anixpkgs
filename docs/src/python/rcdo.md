# rcdo

Run commands on remote machines.

[Repository](https://github.com/goromal/rcdo)

## Usage

```bash
Usage: rcdo [OPTIONS] REMOTE_HOST CMD COMMAND [ARGS]...

  Run a local command `cmd` on a remote machine.

  `remote_host` can be a single or multi-step hop, e.g.,

      user@hostname:password
      user1@hostname1:password+user2@hostname2:password+...

Options:
  -i, --input TEXT   Remote file(s) to grab.
  -o, --output TEXT  Local file(s) to create.
  --ssh-config TEXT  Path to SSH config file.  [default: ~/.ssh/config]
  -v, --verbose      Print out diagnostic information.
  --help             Show this message and exit.

Commands:
  local   The command is from your local machine.
  remote  The command is from the remote machine.
```

