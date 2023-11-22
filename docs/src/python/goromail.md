# python310.pkgs.goromail

Manage mail for GBot and Journal.

The following workflows are supported, all via text messaging:

**GBot (*goromal.bot@gmail.com*):**

- Calorie counts via a solo number (e.g., `100`)
- Tasks via the keywords `P[0-3]:`
  - `P0` = "Must do today"
  - `P1` = "Must do in e.g., next few days"
  - `P2` = "Must do in e.g., next 1-2 weeks"
  - `P3` = "Should do eventually"
- Keyword matchers for routing to specific Wiki pages, which are configurable via a CSV file passed to the `bot` command
- ITNS additions via any other pattern

**Journal (*goromal.journal@gmail.com*):**

- Any pattern will be added to the journal according to the date *in which the message was sent*.

```bash
Usage: goromail [OPTIONS] COMMAND [ARGS]...

  Manage the mail for GBot and Journal.

Options:
  --gmail-secrets-json PATH    GMail client secrets file.
  --gbot-refresh-file PATH     GBot refresh file (if it exists).
  --journal-refresh-file PATH  Journal refresh file (if it exists).
  --num-messages INTEGER       Number of messages to poll for GBot and Journal
                              (each).  [default: 1000]
  --wiki-url TEXT              URL of the DokuWiki instance (https).
  --wiki-secrets-file PATH     Path to the DokuWiki login secrets JSON file.
  --task-secrets-file PATH     Google Tasks client secrets file.
  --task-refresh-token PATH    Google Tasks refresh file (if it exists).
  --enable-logging BOOLEAN     Whether to enable logging.  [default: True]
  --help                       Show this message and exit.

Commands:
  bot      Process all pending bot commands.
  journal  Process all pending journal entries.
```

