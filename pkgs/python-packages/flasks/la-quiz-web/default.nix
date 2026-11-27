{
  buildPythonPackage,
  setuptools,
  pytestCheckHook,
  flask,
  python,
  pkg-src,
}:
let
  pythonLibDir = "lib/python${python.passthru.pythonVersion}/site-packages";
in
buildPythonPackage rec {
  pname = "la-quiz-web";
  version = "0.0.1";
  pyproject = true;
  build-system = [ setuptools ];
  src = "${pkg-src}/la-quiz-web";
  prePatch = ''
    mkdir -p $out/${pythonLibDir}/templates
    cp templates/index.html $out/${pythonLibDir}/templates/index.html
    cp templates/quiz.html $out/${pythonLibDir}/templates/quiz.html
    cp templates/setup_region.html $out/${pythonLibDir}/templates/setup_region.html
  '';
  propagatedBuildInputs = [
    flask
  ];
  nativeCheckInputs = [ pytestCheckHook ];
  pytestFlags = [ "tests" ];
  meta = {
    description = "A web-based LA geography quiz game with mobile support.";
    longDescription = ''
      A mobile-friendly Flask web application for testing knowledge of Los Angeles geography.
      Places are taught a few at a time in rounds: study them on a zoomed map, practice until
      each is answered correctly twice in a row after a miss, then pass a final check with no
      misses. Spaced review brings missed places back in later rounds, and per-place mastery
      persists across visits.
    '';
    autoGenUsageCmd = "--help";
  };
}
