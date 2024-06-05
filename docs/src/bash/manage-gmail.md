# manage-gmail

Interactively manage your GMail inbox from the command line.

Powered by [gmail-parser](../python/gmail-parser.md).

```bash
usage: manage-gmail

Enter an interactive shell for managing a GMail inbox.

Examples:

    [Deleting promotions and social network emails]
      
    >> baseInbox = GMailCorpus('your_email@gmail.com').Inbox(1000)
    >> baseInbox.clean()
    >> baseInbox = GMailCorpus('your_email@gmail.com').Inbox(1000)

    [Get all senders of unread emails]

    >> unreadInbox = baseInbox.fromUnread()
    >> print(unreadInbox.getSenders())

    [Read all unread emails from specific senders]

    >> msgs = unreadInbox.fromSenders(['his@email.com', 'her@email.com']).getMessages()
    >> for msg in msgs:
    >>   print(msg.getText())

    [Mark an entire sub-inbox as read]

    >> subInbox.markAllAsRead()

```


