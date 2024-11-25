{ writeArgparseScriptBin, mkShell, python, color-prints }:
let
  pythonEnv = (python.withPackages (p: with p; [ ipython gmail-parser ]));
  pkgname = "manage-gmail";
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
  '';
  shellFile = ../bash-utils/customShell.nix;
  hookCmd =
    "${color-prints}/bin/echo_yellow 'from gmail_parser.corpus import GMailCorpus'";
in (writeArgparseScriptBin pkgname usage_str [ ] ''
  nix-shell ${shellFile} \
    --arg pkgList "[ ${pythonEnv} ]" \
    --argstr shellName "${pkgname}" \
    --argstr hookCmd "${hookCmd}" \
    --arg colorCode 31 \
    --run "ipython"
'') // {
  meta = {
    description =
      "Interactively manage your GMail inbox from the command line.";
    longDescription = ''
      Powered by [gmail-parser](../python/gmail-parser.md).
    '';
    autoGenUsageCmd = "--help";
  };
}
