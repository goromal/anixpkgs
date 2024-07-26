{ callPackage, pytestCheckHook, buildPythonPackage, easy-google-auth, click
, colorama, gmail-parser, task-tools, wiki-tools }:
callPackage ../pythonPkgFromScript.nix {
  pname = "goromail";
  version = "1.0.0";
  description = "Manage mail for GBot and Journal.";
  script-file = ./cli.py;
  inherit pytestCheckHook buildPythonPackage;
  propagatedBuildInputs = [
    easy-google-auth
    click
    colorama
    gmail-parser
    task-tools
    wiki-tools
  ];
  checkPkgs = [ ];
  longDescription = ''
    The following workflows are supported, all via text messaging:

    **GBot (*goromal.bot@gmail.com*):**

    - Calorie counts via a solo number (e.g., `100`)
    - Tasks via the keywords `P[0-3]:`
      - `P0` = "Must do today"
      - `P1` = "Must do within a week"
      - `P2` = "Must do within a month"
      - `P3` = "Should do eventually"
    - Keyword matchers for routing to specific Wiki pages, which are configurable via a CSV file passed to the `bot` command:
      - `KEYWORD: [P0-1:] ...`
      - `Sort KEYWORD. [P0-1:] ...`
    - ITNS additions via any other pattern

    **Journal (*goromal.journal@gmail.com*):**

    - Any pattern will be added to the journal according to the date *in which the message was sent* **unless** prepended by the string `mm/dd/yyyy:`.
  '';
  autoGenUsageCmd = "--help";
  subCmds = [ "bot" "journal" ];
}
