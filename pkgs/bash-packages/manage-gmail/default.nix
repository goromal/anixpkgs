{ writeShellScriptBin
, mkShell
, python
, color-prints
, callPackage
}:
let
    pythonEnv = (python.withPackages(p: with p; [
        ipython
        gmail-parser
    ]));
    pkgname = "manage-gmail";
    argparse = callPackage ../bash-utils/argparse.nix {
        usage_str = ''
        usage: ${pkgname}

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

        Setup:

            You at least need a Google Drive secrets file:

            ~/google_secrets/pydrive_secrets/client_secrets.json
        '';
        optsWithVarsAndDefaults = [];
    };
    custom-shell-cmd = callPackage ../bash-utils/mkCustomShellCmd.nix {
        pkgList = [ pythonEnv ];
        shellName = pkgname;
        hookCmd = "${color-prints}/bin/echo_yellow 'from gmail_parser.corpus import GMailCorpus'";
        runCmd = "ipython";
    };
in writeShellScriptBin pkgname ''
    ${argparse}
    ${custom-shell-cmd}
''
