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

## Usage (Auto-Generated)

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
  clean         Clean out promotions and social emails.
  gbot-send     Send an email from GBot.
  journal-send  Send an email from Journal.
  send          Send an email.



Usage: gmail-manager clean [OPTIONS]

  Clean out promotions and social emails.

Options:
  --num-messages INTEGER  Number of messages to poll before cleaning.
                          [default: 1000]
  --help                  Show this message and exit.



Usage: gmail-manager send [OPTIONS] RECIPIENT SUBJECT BODY

  Send an email.

Options:
  --help  Show this message and exit.



Usage: gmail-manager gbot-send [OPTIONS] RECIPIENT SUBJECT BODY

  Send an email from GBot.

Options:
  --help  Show this message and exit.



Usage: gmail-manager journal-send [OPTIONS] RECIPIENT SUBJECT BODY

  Send an email from Journal.

Options:
  --help  Show this message and exit.

```

