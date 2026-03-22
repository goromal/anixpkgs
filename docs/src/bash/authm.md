# authm

Manage secrets.


## Usage

```bash
Usage: authm [OPTIONS] COMMAND [ARGS]...

  Manage secrets.

Options:
  --help  Show this message and exit.

Commands:
  refresh   Refresh all auth tokens one-by-one.
  validate  Validate the secrets files present on the filesystem.
```

### refresh


```bash
Usage: authm refresh [OPTIONS]

  Refresh all auth tokens one-by-one.

Options:
  --headless  Run in headless mode.
  --force     Force the auth files to be re-written. If headless, run a
              headless refresh.
  --help      Show this message and exit.
```

### validate


```bash
Usage: authm validate [OPTIONS]

  Validate the secrets files present on the filesystem.

Options:
  --help  Show this message and exit.
```

