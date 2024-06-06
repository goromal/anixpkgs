# book-notes-sync

Utility for syncing Google Play Books notes with my personal wiki.

[Repository](https://github.com/goromal/book-notes-sync)

## Usage (Auto-Generated)

```bash
Usage: book-notes-sync [OPTIONS] COMMAND [ARGS]...

  Synchronize Google Docs book notes with corresponding DokuWiki notes.

Options:
  --docs-secrets-file PATH   Google Docs client secrets file.  [default:
                             /homeless-
                             shelter/secrets/google/client_secrets.json]
  --docs-refresh-token PATH  Google Docs refresh file (if it exists).
                             [default: /homeless-
                             shelter/secrets/google/refresh.json]
  --wiki-url TEXT            URL of the DokuWiki instance (https).  [default:
                             https://notes.andrewtorgesen.com]
  --wiki-secrets-file TEXT   Path to the DokuWiki login secrets JSON file.
                             [default: /homeless-
                             shelter/secrets/wiki/secrets.json]
  --enable-logging BOOLEAN   Whether to enable logging.  [default: True]
  --help                     Show this message and exit.

Commands:
  sync           Sync a single Google Doc with a single DokuWiki page.
  sync-from-csv  Sync a list of Google Docs with DokuWiki pages from a CSV.

```

