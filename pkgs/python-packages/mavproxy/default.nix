{ buildPythonApplication
, lxml
, matplotlib
, numpy
, opencv4
, pymavlink
, pyserial
, setuptools
, wxPython_4_2
, pkg-src
}:
buildPythonApplication rec {
    pname = "MAVProxy";
    version = "1.8.60-beta";
    src = pkg-src;
    postPatch = '' substituteInPlace setup.py --replace "opencv-python" "" '';
    propagatedBuildInputs = [
        lxml
        matplotlib
        numpy
        opencv4
        pymavlink
        pyserial
        setuptools
        wxPython_4_2
    ];
    doCheck = false;
}
