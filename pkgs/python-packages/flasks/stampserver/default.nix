{
  buildPythonPackage,
  setuptools,
  flask,
  flask-login,
  flask-wtf,
  wtforms,
  werkzeug,
  pillow,
  pillow-heif,
  opencv4,
  ffmpeg-headless,
  writeShellScript,
  python,
  pkg-src,
}:
let
  pythonLibDir = "lib/python${python.passthru.pythonVersion}/site-packages";
in
buildPythonPackage rec {
  pname = "stampserver";
  version = "0.0.0";
  pyproject = true;
  build-system = [ setuptools ];
  src = "${pkg-src}/stampserver";
  prePatch = ''
    mkdir -p $out/${pythonLibDir}/templates
    cp index.html $out/${pythonLibDir}/templates/index.html
    cp login.html $out/${pythonLibDir}/templates/login.html
  '';
  makeWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    "${ffmpeg-headless}/bin"
  ];
  propagatedBuildInputs = [
    flask
    flask-login
    flask-wtf
    wtforms
    werkzeug
    pillow
    pillow-heif
    opencv4
  ];
  meta = {
    description = "Provides an interface for stamping metadata on PNGs, JPEGs, HEICs, and MP4s.";
    longDescription = "";
    autoGenUsageCmd = "--help";
  };
}
