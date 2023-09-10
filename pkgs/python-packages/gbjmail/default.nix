{ callPackage, pytestCheckHook, buildPythonPackage, click, colorama
, gmail-parser, task-tools, wiki-tools }:
callPackage ../pythonPkgFromScript.nix {
  pname = "gbjmail";
  version = "1.0.0";
  description = "Manage mail for GBot and Journal.";
  script-file = ./cli.py;
  inherit pytestCheckHook buildPythonPackage;
  propagatedBuildInputs = [ click colorama gmail-parser task-tools wiki-tools ];
  checkPkgs = [ ];
  longDescription = ''
    The following workflows are supported, all via text messaging:

    **GBot (*goromal.bot@gmail.com*):**

    - Calorie counts via a solo number (e.g., `100`)
    - Reminders via `Remind me ...`
    - ITNS additions via any other pattern

    **Journal (*goromal.journal@gmail.com*):**

    - Any pattern will be added to the journal according to the date *in which the message was sent*.

    ```bash
    Usage: gbjmail [OPTIONS] COMMAND [ARGS]...

      Manage the mail for GBot and Journal.

    Options:
      --gmail-secrets-json PATH    GMail client secrets file.  [default:
                                  /data/andrew/secrets/gmail/secrets.json]
      --gbot-refresh-file PATH     GBot refresh file (if it exists).  [default:
                                  /data/andrew/secrets/gmail/bot_refresh.json]
      --journal-refresh-file PATH  Journal refresh file (if it exists).
                                  [default: /data/andrew/secrets/gmail/journal_
                                  refresh.json]
      --num-messages INTEGER       Number of messages to poll for GBot and
                                  Journal (each).  [default: 1000]
      --wiki-url TEXT              URL of the DokuWiki instance (https).
                                  [default: https://notes.andrewtorgesen.com]
      --wiki-secrets-file PATH     Path to the DokuWiki login secrets JSON file.
                                  [default:
                                  /data/andrew/secrets/wiki/secrets.json]
      --task-secrets-file PATH     Google Tasks client secrets file.  [default:
                                  /data/andrew/secrets/task/secrets.json]
      --task-refresh-token PATH    Google Tasks refresh file (if it exists).
                                  [default:
                                  /data/andrew/secrets/task/token.json]
      --enable-logging BOOLEAN     Whether to enable logging.  [default: True]
      --help                       Show this message and exit.

    Commands:
      process  Process all pending commands.
    ```
  '';
}
