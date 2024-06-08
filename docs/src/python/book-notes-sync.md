# book-notes-sync

Utility for syncing Google Play Books notes with my personal wiki.

[Repository](https://github.com/goromal/book-notes-sync)

## Usage (Auto-Generated)

```bash
Usage: book-notes-sync [OPTIONS] COMMAND [ARGS]...

  Synchronize Google Docs book notes with corresponding DokuWiki notes.

Options:
  --docs-secrets-file PATH   Google Docs client secrets file.  [default:
                             ~/secrets/google/client_secrets.json]
  --docs-refresh-token PATH  Google Docs refresh file (if it exists).
                             [default: ~/secrets/google/refresh.json]
  --wiki-url TEXT            URL of the DokuWiki instance (https).  [default:
                             https://notes.andrewtorgesen.com]
  --wiki-secrets-file TEXT   Path to the DokuWiki login secrets JSON file.
                             [default: ~/secrets/wiki/secrets.json]
  --enable-logging BOOLEAN   Whether to enable logging.  [default: True]
  --help                     Show this message and exit.

Commands:
  sync           Sync a single Google Doc with a single DokuWiki page.
  sync-from-csv  Sync a list of Google Docs with DokuWiki pages from a CSV.



Usage: book-notes-sync sync [OPTIONS]

  Sync a single Google Doc with a single DokuWiki page.

Options:
  --docs-id TEXT  Document ID of the Google Doc.  [required]
  --page-id TEXT  ID of the DokuWiki page.  [required]
  --help          Show this message and exit.



Usage: book-notes-sync sync-from-csv [OPTIONS]

  Sync a list of Google Docs with DokuWiki pages from a CSV.

Options:
  --sync-csv PATH  CSV specifying (docs-id, page-id) pairs.  [default:
                   ~/configs/book-notes.csv]
  --help           Show this message and exit.

```

