# rcrsync_ui

Web UI to run rcrsync and see when each cloud directory was last pushed and pulled

Serves /rcrsync, which lists each rcrsync directory with the time of its last push (override, mirror or sync) and last pull (init, copy or sync), read from the rcrsync history file and seeded from rclone's bisync cache, and runs rcrsync commands on whole directories or subdirectories.
## Usage

```bash
usage: rcrsync_ui [-h] [--port PORT] [--subdomain SUBDOMAIN] --config CONFIG
                  [--rcrsync RCRSYNC]

Web UI for the rcrsync cloud directory tool

options:
  -h, --help            show this help message and exit
  --port PORT
  --subdomain SUBDOMAIN
  --config CONFIG       JSON file with home_dir and dirs [{name, cloudname,
                        dirname}]
  --rcrsync RCRSYNC     rcrsync executable
```

