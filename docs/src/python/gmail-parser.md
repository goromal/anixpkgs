# python310.pkgs.gmail-parser

Assorted Python tools for semi-automated processing of GMail messages.

[Repository](https://github.com/goromal/gmail_parser)

## Setup

You at least need a Google Drive API secrets file set up at `~/secrets/pydrive/client_secrets.json`.

## Usage Examples

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

