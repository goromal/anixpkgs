{
  buildPythonPackage,
  setuptools,
  flask,
  ffmpeg-headless,
  ttvd,
  python,
}:
let
  pythonLibDir = "lib/python${python.passthru.pythonVersion}/site-packages";
in
buildPythonPackage rec {
  pname = "ttvdserver";
  version = "0.0.0";
  pyproject = true;
  build-system = [ setuptools ];
  src = ./.;
  prePatch = ''
    mkdir -p $out/${pythonLibDir}/templates
    cp ${./templates/index.html} $out/${pythonLibDir}/templates/index.html
  '';
  makeWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    "${ffmpeg-headless}/bin"
  ];
  propagatedBuildInputs = [
    flask
    ttvd
  ];
  meta = {
    description = "Provides a web UI for downloading TikTok videos via ttvd.";
    longDescription = "";
    autoGenUsageCmd = "--help";
  };
}
