{
  buildPythonPackage,
  setuptools,
  flask,
  requests,
  python,
}:
let
  pythonLibDir = "lib/python${python.passthru.pythonVersion}/site-packages";
in
buildPythonPackage rec {
  pname = "disciple";
  version = "0.0.1";
  pyproject = true;
  build-system = [ setuptools ];
  src = ./.;
  prePatch = ''
    mkdir -p $out/${pythonLibDir}/templates
    cp ${./templates/base.html}        $out/${pythonLibDir}/templates/base.html
    cp ${./templates/study.html}       $out/${pythonLibDir}/templates/study.html
    cp ${./templates/browse.html}      $out/${pythonLibDir}/templates/browse.html
    cp ${./templates/tags.html}        $out/${pythonLibDir}/templates/tags.html
    cp ${./templates/tag_detail.html}  $out/${pythonLibDir}/templates/tag_detail.html
    cp ${./templates/manage_tags.html} $out/${pythonLibDir}/templates/manage_tags.html
  '';
  propagatedBuildInputs = [
    flask
    requests
  ];
  meta = {
    description = "A Book of Mormon Christ-reference study tool.";
    autoGenUsageCmd = "--help";
  };
}
