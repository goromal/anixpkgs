{
  buildPythonPackage,
  setuptools,
  flask,
  python,
}:
let
  pythonLibDir = "lib/python${python.passthru.pythonVersion}/site-packages";
in
buildPythonPackage rec {
  pname = "la-quiz-web";
  version = "0.0.1";
  pyproject = true;
  build-system = [ setuptools ];
  src = ./.;
  prePatch = ''
    mkdir -p $out/${pythonLibDir}/templates
    cp ${./templates/index.html} $out/${pythonLibDir}/templates/index.html
    cp ${./templates/quiz.html} $out/${pythonLibDir}/templates/quiz.html
    cp ${./templates/setup_region.html} $out/${pythonLibDir}/templates/setup_region.html
  '';
  propagatedBuildInputs = [
    flask
  ];
  meta = {
    description = "A web-based LA geography quiz game with mobile support.";
    longDescription = ''
      A mobile-friendly Flask web application for testing knowledge of Los Angeles geography.
      Users tap locations on a map to identify cities across different regions.
      Features include score tracking, responsive design, and touch support.
    '';
    autoGenUsageCmd = "--help";
  };
}
