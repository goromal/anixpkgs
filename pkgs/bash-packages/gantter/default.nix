{
  callPackage,
  writeArgparseScriptBin,
  python,
  blank-svg,
  svg,
  pdf,
  color-prints,
  redirects,
}:
let
  pkgname = "gantter";
  texmaker =
    with python.pkgs;
    (callPackage ../../python-packages/pythonPkgFromScript.nix {
      pname = "texmaker";
      version = "0.0.0";
      description = ".tex worker script for gantter.";
      script-file = ./texmaker.py;
      inherit pytestCheckHook buildPythonPackage setuptools;
      propagatedBuildInputs = [
        numpy
        scipy
      ];
      checkPkgs = [ ];
    });
  printErr = "${color-prints}/bin/echo_red";
  printInfo = "${color-prints}/bin/echo_yellow";
  printGrn = "${color-prints}/bin/echo_green";
in
(writeArgparseScriptBin pkgname
  ''
    usage: ${pkgname} specfile

    Create a Gantt-based dependency chart for tasks, laid out by the specfile.
    Example specfile contents:
    --------------------------------------------------------------------------
    1>> Coverage Planner
    1.1>> Learn interface for outer loop
    1.2>> [[1.1]] ((2)) Connect Lab 4 code with outer loop
    1.3>> [[2.1]] [[3.1]] ((3)) Waiting for SLAM

    2>> SLAM Algorithm
    2.1>> Something

    3>> System-Level Evaluation
    3.1>> Another thing
    --------------------------------------------------------------------------
    Double brackets [[]] indicate dependencies and double parentheses (()) 
    indicate estimated time units required (assumes 1 if none given).

    REQUIRES pdflatex to be in your system path (not interested in shipping 
    texlive-full in its entirety with this little tool).
  ''
  [ ]
  ''
    if [[ ! -f "$1" ]]; then
      ${printErr} "No valid specfile given! Exiting..."
      exit
    fi

    specfile=$(realpath "$1")

    CALLDIR="$PWD"

    cd $(mktemp -d)
    tempdir=$(pwd)
    mkdir figs
    cp ${blank-svg.data} figs/${blank-svg.name}

    ${printInfo} "Finding optimal schedule..."

    figlist=$(${texmaker}/bin/texmaker "$specfile" "figs/${blank-svg.name}" "figs" "${pdf}/bin/pdf")

    for figname in $figlist; do
      mv "figs/$figname" .
    done

    pdflatex *.tex ${redirects.suppress_all}

    for figname in $figlist; do
      rm "$figname"
    done

    ganttpdffile="$(ls *.pdf)"

    mv "$ganttpdffile" "$CALLDIR"

    cd "$CALLDIR" && rm -rf "$tempdir"

    ${printInfo} "Converting figure to scalable vector graphic..."

    ${svg}/bin/svg --crop --poppler "$ganttpdffile" "$ganttpdffile" ${redirects.suppress_all}

    rm "$ganttpdffile"

    ${printGrn} "Done."
  ''
)
// {
  meta = {
    description = "Generate Gantt charts from text files.";
    longDescription = "";
    autoGenUsageCmd = "--help";
  };
}
