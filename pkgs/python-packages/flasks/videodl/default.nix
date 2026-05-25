{
  buildPythonPackage,
  setuptools,
  flask,
  ffmpeg-headless,
  yt-dlp,
  python,
}:
let
  pythonLibDir = "lib/python${python.passthru.pythonVersion}/site-packages";
in
buildPythonPackage rec {
  pname = "vdlserver";
  version = "0.0.0";
  pyproject = true;
  build-system = [ setuptools ];
  src = ./.;
  prePatch = ''
    mkdir -p $out/${pythonLibDir}/templates
    cp ${./templates/index.html} $out/${pythonLibDir}/templates/index.html
  '';
  makeWrapperArgs = [
    "--prefix" "PATH" ":" "${yt-dlp}/bin"
    "--prefix" "PATH" ":" "${ffmpeg-headless}/bin"
  ];
  propagatedBuildInputs = [ flask ];
  meta = {
    description = "Web UI for downloading videos from YouTube, TikTok, and more via yt-dlp.";
    longDescription = "";
    autoGenUsageCmd = "--help";
  };
}
