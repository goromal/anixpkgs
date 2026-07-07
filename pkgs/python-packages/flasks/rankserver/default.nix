{
  buildPythonPackage,
  setuptools,
  pytestCheckHook,
  flask,
  flask-login,
  flask-wtf,
  wtforms,
  werkzeug,
  pysorting,
  pillow,
  ffmpeg-headless,
  strings,
  redirects,
  writeTextFile,
  callPackage,
  writeShellScript,
  python,
}:
let
  pythonLibDir = "lib/python${python.passthru.pythonVersion}/site-packages";
in
buildPythonPackage rec {
  pname = "rankserver";
  version = "0.0.1";
  pyproject = true;
  build-system = [ setuptools ];
  src = ./.;
  prePatch = ''
    mkdir -p $out/${pythonLibDir}/templates
    cp ${./index.html} $out/${pythonLibDir}/templates/index.html
    cp ${./login.html} $out/${pythonLibDir}/templates/login.html
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
    pysorting
    pillow
  ];
  nativeCheckInputs = [ pytestCheckHook ];
  meta = {
    description = "A portable webserver for ranking files via binary manual comparisons, powered by Python's flask library.";
    longDescription = ''
      Spins up a flask webserver (on the specified port) whose purpose is to help a user rank files in the chosen `data-dir` directory via manual binary comparisons. The ranking is done via an incremental "RESTful" sorting strategy implemented within the [pysorting](./pysorting.md) library. State is created and maintained within the `data-dir` directory so that the ranking exercise can pick back up where it left off between different spawnings of the server. At this point, only the ranking of `.txt`, `.png`, and `.mp4` files is possible; other file types in `data-dir` will be ignored.

      A rankables directory may optionally "watch" a stampserver directory via `rank_config.json` (configured in the UI): files carrying a chosen stamp tag are mirrored in as symlinks, removals are absorbed with minimal lost comparison work, and newly stamped files are placed into an existing ranking via binary insertion.
    '';
    autoGenUsageCmd = "--help";
  };
}
