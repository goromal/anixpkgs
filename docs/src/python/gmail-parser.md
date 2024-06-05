# gmail-parser

Assorted Python tools for semi-automated processing of GMail messages.

[Repository](https://github.com/goromal/gmail_parser)

This package may be used either in CLI form or via an interactive Python shell.

## Usage Examples (CLI)

```bash
Usage: gmail-manager [OPTIONS] COMMAND [ARGS]...

  Manage GMail.

Options:
  --gmail-secrets-json PATH  GMail client secrets file.  [default:
                            /data/andrew/secrets/gmail/secrets.json]
  --gmail-refresh-file PATH  GMail refresh file (if it exists).  [default:
                            /data/andrew/secrets/gmail/refresh.json]
  --enable-logging BOOLEAN   Whether to enable logging.  [default: False]
  --help                     Show this message and exit.

Commands:
  clean  Clean out promotions and social emails.
```

## Usage Examples (Interactive Shell)

Import with

```python
from gmail_parser.corpus import GMailCorpus
```

Deleting promotions and social network emails:

```python
inbox = GMailCorpus('your_email@gmail.com').Inbox(1000)
inbox.clean()
inbox = GMailCorpus('your_email@gmail.com').Inbox(1000)
```

Get all senders of unread emails:

```python
unread = inbox.fromUnread()
print(unread.getSenders())
```

Read all unread emails from specific senders:

```python
msgs = unread.fromSenders(['his@email.com', 'her@email.com']).getMessages()
for msg in msgs:
    print(msg.getText())
```

Mark an entire sub-inbox as read:

```python
subInbox.markAllAsRead()
```


