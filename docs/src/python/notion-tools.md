# notion-tools

Tools for interacting with Notion.

[Repository](https://github.com/goromal/notion-tools)

## Usage

```bash
Usage: notion-tools [OPTIONS] COMMAND [ARGS]...

  Interact with Notion pages.

Options:
  --token-file PATH  Notion API token secrets file.  [default:
                     ~/secrets/notion/secret.json]
  --help             Show this message and exit.

Commands:
  annotate        Count bullets and action items on a page and retitle it...
  append          Append text as a bulleted list to a Notion page.
  create-subpage  Create a new child page under a parent page and print...
  get-blocks      Fetch the block content of a Notion page as JSON.
  list-blocks     List blocks on a page as tab-separated block_id, type,...
  list-subpages   List sub-pages referenced from a page as tab-separated...
  move-block      Move a block from its current page to a destination page.
  set-title       Update the title of a Notion page.
```

### append


```bash
Usage: notion-tools append [OPTIONS] PAGE_ID

  Append text as a bulleted list to a Notion page.

Options:
  --file PATH     File containing text to append.
  --content TEXT  Text to append if --file is not specified. NOTE: This
                  argument is mutually exclusive with content_file
  --help          Show this message and exit.
```

### annotate


```bash
Usage: notion-tools annotate [OPTIONS] KEYWORD PAGE_ID

  Count bullets and action items on a page and retitle it with the counts.

Options:
  --dry-run  Count but don't update the page title.
  --help     Show this message and exit.
```

### create-subpage


```bash
Usage: notion-tools create-subpage [OPTIONS] PARENT_PAGE_ID TITLE

  Create a new child page under a parent page and print its page_id.

Options:
  --help  Show this message and exit.
```

### get-blocks


```bash
Usage: notion-tools get-blocks [OPTIONS] PAGE_ID

  Fetch the block content of a Notion page as JSON.

Options:
  --output TEXT  Output file path. Prints to stdout if not specified.
                 [default: ""]
  --help         Show this message and exit.
```

### list-blocks


```bash
Usage: notion-tools list-blocks [OPTIONS] PAGE_ID

  List blocks on a page as tab-separated block_id, type, text.

Options:
  --type TEXT  Filter by block type (e.g. bulleted_list_item).
  --help       Show this message and exit.
```

### list-subpages


```bash
Usage: notion-tools list-subpages [OPTIONS] PAGE_ID

  List sub-pages referenced from a page as tab-separated page_id, title.

Options:
  --help  Show this message and exit.
```

### move-block


```bash
Usage: notion-tools move-block [OPTIONS] BLOCK_ID DEST_PAGE_ID

  Move a block from its current page to a destination page.

Options:
  --help  Show this message and exit.
```

### set-title


```bash
Usage: notion-tools set-title [OPTIONS] PAGE_ID TITLE

  Update the title of a Notion page.

Options:
  --help  Show this message and exit.
```

