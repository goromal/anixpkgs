# wiki-tools

CLI tools for managing my wiki notes site.

[Repository](https://github.com/goromal/wiki-tools)

## Usage (Auto-Generated)

```bash
Usage: wiki-tools [OPTIONS] COMMAND [ARGS]...

  Read and edit DokuWiki instance pages.

Options:
  --url TEXT                URL of the DokuWiki instance (https).  [default:
                            https://notes.andrewtorgesen.com]
  --secrets-file PATH       Path to the DokuWiki login secrets JSON file.
                            [default: /homeless-
                            shelter/secrets/wiki/secrets.json]
  --enable-logging BOOLEAN  Whether to enable logging.  [default: False]
  --help                    Show this message and exit.

Commands:
  get               Read the content of a DokuWiki page.
  get-md            Read the content of a DokuWiki page in Markdown format.
  get-rand-journal  Get a random journal entry between 2013 and now.
  put               Put content onto a DokuWiki page.
  put-dir           Put a directory of pages into a DokuWiki namespace.
  put-md            Put Markdown content onto a DokuWiki page.
  put-md-dir        Put a directory of Markdown pages into a DokuWiki...

```

