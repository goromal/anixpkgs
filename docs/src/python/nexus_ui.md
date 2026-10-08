# nexus_ui

LAN hub UI for machine status and bulk anix-upgrade

Discovers opted-in LAN machines over mDNS, links to each machine's landing page, shows online status and versions, and fans out anix-upgrade runs to selected machines.
## Usage

```bash
usage: nexus-ui [-h] [--port PORT] [--subdomain SUBDOMAIN]
                [--state-dir STATE_DIR] [--avahi-browse-bin AVAHI_BROWSE_BIN]

options:
  -h, --help            show this help message and exit
  --port PORT
  --subdomain SUBDOMAIN
  --state-dir STATE_DIR
                        Directory for the persisted machine roster
  --avahi-browse-bin AVAHI_BROWSE_BIN
                        avahi-browse command used for mDNS discovery
```

