# goromail

Manage mail for GBot and Journal.

The following workflows are supported, all via text messaging:

**GBot (*goromal.bot@gmail.com*):**

- Calorie counts via a solo number (e.g., `100`)
- Tasks via the keywords `P[0-3]:`
  - `P0` = "Must do today"
  - `P1` = "Must do within a week"
  - `P2` = "Must do within a month"
  - `P3` = "Should do eventually"
- Keyword matchers for routing to specific Wiki pages, which are configurable via a CSV file passed to the `bot` command:
  - `KEYWORD: [P0-1:] ...`
  - `Sort KEYWORD. [P0-1:] ...`
- ITNS additions via any other pattern

**Journal (*goromal.journal@gmail.com*):**

- Any pattern will be added to the journal according to the date *in which the message was sent* **unless** prepended by the string `mm/dd/yyyy:`.

## Usage (Auto-Generated)

```bash
Usage: goromail [OPTIONS] COMMAND [ARGS]...

  Manage the mail for GBot and Journal.

Options:
  --gmail-secrets-json PATH    GMail client secrets file.  [default:
                               /homeless-
                               shelter/secrets/google/client_secrets.json]
  --gbot-refresh-file PATH     GBot refresh file (if it exists).  [default:
                               /homeless-
                               shelter/secrets/google/bot_refresh.json]
  --journal-refresh-file PATH  Journal refresh file (if it exists).  [default:
                               /homeless-
                               shelter/secrets/google/journal_refresh.json]
  --num-messages INTEGER       Number of messages to poll for GBot and Journal
                               (each).  [default: 1000]
  --wiki-url TEXT              URL of the DokuWiki instance (https).
                               [default: https://notes.andrewtorgesen.com]
  --wiki-secrets-file PATH     Path to the DokuWiki login secrets JSON file.
                               [default: /homeless-
                               shelter/secrets/wiki/secrets.json]
  --task-secrets-file PATH     Google Tasks client secrets file.  [default:
                               /homeless-
                               shelter/secrets/google/client_secrets.json]
  --task-refresh-token PATH    Google Tasks refresh file (if it exists).
                               [default: /homeless-
                               shelter/secrets/google/refresh.json]
  --enable-logging BOOLEAN     Whether to enable logging.  [default: False]
  --headless                   Whether to run in headless (i.e., server) mode.
  --headless-logdir PATH       Directory in which to store log files for
                               headless mode.  [default: /homeless-
                               shelter/goromail]
  --help                       Show this message and exit.

Commands:
  bot      Process all pending bot commands.
  journal  Process all pending journal entries.

```

