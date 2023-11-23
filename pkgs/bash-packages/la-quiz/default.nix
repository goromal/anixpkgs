{ callPackage, writeShellScriptBin, python, color-prints, pkgData }:
let
  pkgname = "la-quiz";
  quiz = with python.pkgs;
    (callPackage ../../python-packages/pythonPkgFromScript.nix {
      pname = "quiz";
      version = "0.0.0";
      description = "LA quiz driver.";
      script-file = ./quiz.py;
      inherit pytestCheckHook buildPythonPackage;
      propagatedBuildInputs = [ tkinter pillow ];
      checkPkgs = [ ];
    });
  argparse = callPackage ../bash-utils/argparse.nix {
    usage_str = ''
      usage: ${pkgname} [options] [N|C|E|S]

      Spawn a LA geography quiz! Will pull up the general region you specify:

          N = North
          C = Central
          E = East
          S = South

      Options:

      --debug|-d    Open in debug mode (will print click positions to the screen).

      NOTE: This program assumes that you have the place location JSON files stored in

        ~/games/la-quiz/GLAA-C.json
                        GLAA-E.json
                        GLAA-N.json
                        GLAA-S.json
    '';
    optsWithVarsAndDefaults = [{
      var = "isdebug";
      isBool = true;
      default = "0";
      flags = "--debug|-d";
    }];
  };
  printErr = "${color-prints}/bin/echo_red";
in (writeShellScriptBin pkgname ''
  ${argparse}
  if [[ -z "$1" ]]; then
    ${printErr} "No LA region specified."
    exit 1
  fi
  if [[ "$1" == "N" ]]; then
    imgfile=${pkgData.apps.la-quiz.N-img.data}
    jsonfile="$HOME/games/la-quiz/GLAA-N.json"
  elif [[ "$1" == "C" ]]; then
    imgfile=${pkgData.apps.la-quiz.C-img.data}
    jsonfile="$HOME/games/la-quiz/GLAA-C.json"
  elif [[ "$1" == "E" ]]; then
    imgfile=${pkgData.apps.la-quiz.E-img.data}
    jsonfile="$HOME/games/la-quiz/GLAA-E.json"
  elif [[ "$1" == "S" ]]; then
    imgfile=${pkgData.apps.la-quiz.S-img.data}
    jsonfile="$HOME/games/la-quiz/GLAA-S.json"
  else
    ${printErr} "Unrecognized region option: $1"
    exit 1
  fi
  if [[ "$isdebug" == "1" ]]; then
    ${quiz}/bin/quiz "$imgfile" "$jsonfile" d
  else
    ${quiz}/bin/quiz "$imgfile" "$jsonfile"
  fi
'') // {
  meta = {
    description = "Spawn a LA geography quiz.";
    longDescription = ''
      ```
      usage: ${pkgname} [options] [N|C|E|S]

      Spawn a LA geography quiz! Will pull up the general region you specify:

          N = North
          C = Central
          E = East
          S = South

      Options:

      --debug|-d    Open in debug mode (will print click positions to the screen).

      NOTE: This program assumes that you have the place location JSON files stored in

        ~/games/la-quiz/GLAA-C.json
                        GLAA-E.json
                        GLAA-N.json
                        GLAA-S.json
      ```
    '';
  };
}
