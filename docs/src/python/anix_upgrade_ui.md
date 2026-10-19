# anix_upgrade_ui

Web UI for triggering anix-upgrade

Provides a browser-based interface for running anix-upgrade and viewing its output.
## Usage

```bash
usage: anix-upgrade-ui [-h] [--port PORT] [--subdomain SUBDOMAIN]
                       [--anix-upgrade-bin ANIX_UPGRADE_BIN]
                       [--state-dir STATE_DIR] [--bitctl-bin BITCTL_BIN]

options:
  -h, --help            show this help message and exit
  --port PORT
  --subdomain SUBDOMAIN
  --anix-upgrade-bin ANIX_UPGRADE_BIN
                        Path to the anix-upgrade binary
  --state-dir STATE_DIR
                        Directory for run log and state persistence
  --bitctl-bin BITCTL_BIN
                        Path to bitctl; enables the read-only health API
```

