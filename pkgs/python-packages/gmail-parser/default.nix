{ buildPythonPackage
, pythonOlder
, google-api-python-client
, pydrive2
, google-auth
, google-auth-oauthlib
, oauth2client
, html2text
, progressbar2
, pkg-src
}:
buildPythonPackage rec {
    pname = "gmail_parser";
    version = "0.0.0";
    disabled = pythonOlder "3.8";
    propagatedBuildInputs = [
        google-api-python-client
        pydrive2
        google-auth
        google-auth-oauthlib
        oauth2client
        html2text
        progressbar2
    ];
    src = pkg-src;
    meta = {
        description = "Assorted Python tools for semi-automated processing of GMail messages.";
        longDescription = ''
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
        '';
    };
}
