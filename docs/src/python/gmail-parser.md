# gmail-parser

Assorted Python tools for semi-automated processing of GMail messages.

[Repository](https://github.com/goromal/gmail_parser)

This package may be used either in CLI form or via an interactive Python shell.

## Interactive Shell

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

## Usage

```bash
Usage: gmail-manager [OPTIONS] COMMAND [ARGS]...

  Manage GMail.

Options:
  --gmail-secrets-json PATH    GMail client secrets file.  [default:
                               ~/secrets/google/client_secrets.json]
  --gmail-refresh-file PATH    GMail refresh file (if it exists).  [default:
                               ~/secrets/google/refresh.json]
  --gbot-refresh-file PATH     GBot refresh file (if it exists).  [default:
                               ~/secrets/google/bot_refresh.json]
  --journal-refresh-file PATH  Journal refresh file (if it exists).  [default:
                               ~/secrets/google/journal_refresh.json]
  --enable-logging BOOLEAN     Whether to enable logging.  [default: False]
  --help                       Show this message and exit.

Commands:
  archive-delete  Permanently delete one archived email by LABEL and...
  archive-index   Print the archived-email index as JSON.
  clean           Clean out promotions and social emails.
  gbot-send       Send an email from GBot.
  journal-send    Send an email from Journal.
  process         Apply label->action rules from CONFIG to the latest N...
  send            Send an email.
```

### clean


```bash
Usage: gmail-manager clean [OPTIONS]

  Clean out promotions and social emails.

Options:
  --num-messages INTEGER  Number of messages to poll before cleaning.
                          [default: 1000]
  --help                  Show this message and exit.
```

### process


```bash
Usage: gmail-manager process [OPTIONS]

  Apply label->action rules from CONFIG to the latest N messages.

  Emits one JSON progress event per line to stdout (consumed by the Mail UI),
  then a final {"summary": ...} line.

Options:
  --config PATH           Label->action rules config (pipe-delimited
                          LABEL|ACTION).  [default: ~/configs/mail-clean.csv]
  --archive-root PATH     Directory under which archived emails are written.
                          [default: ~/data/gmail]
  --num-messages INTEGER  Number of latest messages to load and process.
                          [default: 1000]
  --help                  Show this message and exit.
```

### archive-index


```bash
Usage: gmail-manager archive-index [OPTIONS]

  Print the archived-email index as JSON.

Options:
  --archive-root PATH  Directory under which archived emails are written.
                       [default: ~/data/gmail]
  --help               Show this message and exit.
```

### archive-delete


```bash
Usage: gmail-manager archive-delete [OPTIONS] LABEL MESSAGE_ID

  Permanently delete one archived email by LABEL and MESSAGE_ID.

Options:
  --archive-root PATH  Directory under which archived emails are written.
                       [default: ~/data/gmail]
  --help               Show this message and exit.
```

### send


```bash
Usage: gmail-manager send [OPTIONS] RECIPIENT SUBJECT BODY

  Send an email.

Options:
  --help  Show this message and exit.
```

### gbot-send


```bash
Usage: gmail-manager gbot-send [OPTIONS] RECIPIENT SUBJECT BODY

  Send an email from GBot.

Options:
  --help  Show this message and exit.
```

### journal-send


```bash
Usage: gmail-manager journal-send [OPTIONS] RECIPIENT SUBJECT BODY

  Send an email from Journal.

Options:
  --help  Show this message and exit.
```

