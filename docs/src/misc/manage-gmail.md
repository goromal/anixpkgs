# manage-gmail

Interactively manage your GMail inbox from the command line.

```
usage: manage-gmail

Enter an interactive shell for managing a GMail inbox.

Examples:

>> from gmail_parser.corpus import GMailCorpus

[Deleting promotions and social network emails]

>> inbox = GMailCorpus('your_email@gmail.com').Inbox(1000)
>> inbox.clean()
>> inbox = GMailCorpus('your_email@gmail.com').Inbox(1000)

[Get all senders of unread emails]

>> unreadInbox = inbox.fromUnread()
>> print(unreadInbox.getSenders())

[Read all unread emails from specific senders]

>> msgs = unreadInbox.fromSenders(['his@email.com', 'her@email.com']).getMessages()
>> for msg in msgs:
>>   print(msg.getText())

[Mark an entire sub-inbox as read]

>> subInbox.markAllAsRead()

Setup:

    You at least need a Google Drive secrets file:

    ~/secrets/pydrive/client_secrets.json
```

