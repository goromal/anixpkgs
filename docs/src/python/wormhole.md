# wormhole

Local-or-remote (ssh) file operations shared by the flasks UIs, plus a `wormhole` CLI.

Stdlib-only helpers for listing, reading, writing, and deleting files
either on the local filesystem or on a remote host over ssh (BatchMode,
argv-array subprocess calls, shlex-quoted remote paths). Consuming
services must have openssh on their PATH for remote operations.

The `wormhole` command exposes the host resolver used for LAN/VPN
access: `wormhole resolve <name>.local` prints the direct LAN IP from
~/secrets/<name>/i.txt (needed over the VPN, where mDNS does not
propagate), or echoes the host back unchanged.

## Usage

```bash
usage: wormhole [-h] {resolve} ...

Local-or-remote (ssh) file operations over the LAN/VPN.

positional arguments:
  {resolve}
    resolve   Resolve <name>.local to its LAN IP via ~/secrets/<name>/i.txt,
              or echo the host back unchanged.

options:
  -h, --help  show this help message and exit
```

### resolve


```bash
usage: wormhole resolve [-h] host

positional arguments:
  host        host to resolve, e.g. jetson-orin-nx.local

options:
  -h, --help  show this help message and exit
```

