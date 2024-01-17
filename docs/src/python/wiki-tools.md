# wiki-tools

CLI tools for managing my wiki notes site.

[Repository](https://github.com/goromal/wiki-tools)

## Usage

```bash
Usage: wiki-tools [OPTIONS] COMMAND [ARGS]...

  Read and edit DokuWiki instance pages.

Options:
  --url TEXT                URL of the DokuWiki instance (https).  [default:
                            https://notes.andrewtorgesen.com]
  --secrets-file PATH       Path to the DokuWiki login secrets JSON file.
                            [default: /data/andrew/secrets/wiki/secrets.json]
  --enable-logging BOOLEAN  Whether to enable logging.  [default: False]
  --help                    Show this message and exit.

Commands:
  get     Read the content of a DokuWiki page.
  get-md  Read the content of a DokuWiki page in Markdown format.
  put     Put content onto a DokuWiki page.
  put-md  Put Markdown content onto a DokuWiki page.
```

### Get

```bash
Usage: wiki-tools get [OPTIONS]

  Read the content of a DokuWiki page.

Options:
  --page-id TEXT  ID of the DokuWiki page.  [required]
  --output TEXT   Output text file name. Will print to terminal if not
                  specified.
  --help          Show this message and exit.
```

### Get Markdown

```bash
Usage: wiki-tools get-md [OPTIONS]

  Read the content of a DokuWiki page in Markdown format.

Options:
  --page-id TEXT  ID of the DokuWiki page.  [required]
  --output TEXT   Output Markdown file name. Will print to terminal if not
                  specified.
  --help          Show this message and exit.
```

### Put

```bash
Usage: wiki-tools put [OPTIONS]

  Put content onto a DokuWiki page.

Options:
  --page-id TEXT  ID of the DokuWiki page.  [required]
  --file PATH     File containing the target content.
  --content TEXT  Content to put on the page if file is not specified. NOTE:
                  This argument is mutually exclusive with content_file
  --help          Show this message and exit.
```

### Put Markdown

```bash
Usage: wiki-tools put-md [OPTIONS]

  Put Markdown content onto a DokuWiki page.

Options:
  --page-id TEXT  ID of the DokuWiki page.  [required]
  --file PATH     Markdown file containing the target content.
  --content TEXT  Markdown content to put on the page if file is not
                  specified. NOTE: This argument is mutually exclusive with
                  content_file
  --help          Show this message and exit.
```

