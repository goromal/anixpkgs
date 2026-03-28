{
  buildPythonPackage,
  setuptools,
  flask,
  anthropic,
  requests,
  beautifulsoup4,
  python,
}:
let
  pythonLibDir = "lib/python${python.passthru.pythonVersion}/site-packages";
in
buildPythonPackage rec {
  pname = "tester";
  version = "0.0.1";
  pyproject = true;
  build-system = [ setuptools ];
  src = ./.;
  prePatch = ''
    mkdir -p $out/${pythonLibDir}/templates
    cp ${./templates/base.html}      $out/${pythonLibDir}/templates/base.html
    cp ${./templates/index.html}     $out/${pythonLibDir}/templates/index.html
    cp ${./templates/create.html}    $out/${pythonLibDir}/templates/create.html
    cp ${./templates/take_rote.html} $out/${pythonLibDir}/templates/take_rote.html
    cp ${./templates/take_mc.html}   $out/${pythonLibDir}/templates/take_mc.html
    cp ${./templates/take_sa.html}   $out/${pythonLibDir}/templates/take_sa.html
    cp ${./templates/result.html}    $out/${pythonLibDir}/templates/result.html
    cp ${./templates/results.html}   $out/${pythonLibDir}/templates/results.html
  '';
  propagatedBuildInputs = [
    flask
    anthropic
    requests
    beautifulsoup4
  ];
  meta = {
    description = "A self-testing and exam tool with rote, multiple choice, and short answer modes.";
    longDescription = ''
      A Flask web application for accumulating and taking mini exams to test
      memorization and knowledge of particular subjects. Supports rote memorization
      checks (fuzzy-graded fill-in-the-blank), multiple choice tests (AI-generated,
      locally graded), and short answer tests (AI-generated and AI-graded).
      Exam definitions and results are stored in a persistent SQLite database.
    '';
    autoGenUsageCmd = "--help";
  };
}
