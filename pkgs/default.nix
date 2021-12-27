final: prev: 
with prev.lib;
let
    pythonOverridesFor = superPython: fix (python: superPython.override ({
        packageOverrides ? _: _: {}, ...
    }: {
        self = python;
        packageOverrides = composeExtensions packageOverrides (pySelf: pySuper: {
            geometry = pySelf.callPackage ./python-packages/geometry {
                callPackage = prev.callPackage;
                stdenv = prev.clangStdenv;
                cmake = prev.cmake;
                manif-geom-cpp = final.manif-geom-cpp;
                eigen = prev.eigen;
                pybind11 = python.pkgs.pybind11;
                inherit python;
                buildPythonPackage = pySelf.buildPythonPackage;
            };
            norbert = pySelf.callPackage ./python-packages/norbert {
                buildPythonPackage = pySelf.buildPythonPackage;
                fetchPypi = pySelf.fetchPypi;
                pythonOlder = pySelf.pythonOlder;
                scipy = python.pkgs.scipy;
            };
            spleeter = pySelf.callPackage ./python-packages/spleeter {
                buildPythonPackage = pySelf.buildPythonPackage;
                fetchPypi = pySelf.fetchPypi;
                pythonOlder = pySelf.pythonOlder;
                ffmpeg = prev.ffmpeg;
                libsndfile = prev.libsndfile;
                ffmpeg-python = python.pkgs.ffmpeg-python;
                pandas = python.pkgs.pandas;
                tensorflow = python.pkgs.tensorflow;
                norbert = python.pkgs.norbert;
                typer = python.pkgs.typer;
                llvmlite = pySelf.llvmlite;
                numpy = python.pkgs.numpy;
                httpx = python.pkgs.httpx;
                librosa = python.pkgs.librosa;
            };
        });
    }));
in {
    manif-geom-cpp = prev.callPackage ./cxx-packages/manif-geom-cpp {
        stdenv = prev.clangStdenv;
        cmake = prev.cmake;
        eigen = prev.eigen;
        boost = prev.boost;
    };
    
    python27 = pythonOverridesFor prev.python27;
    python37 = pythonOverridesFor prev.python37;
    python38 = pythonOverridesFor prev.python38;
    python39 = pythonOverridesFor prev.python39;
    python310 = pythonOverridesFor prev.python310;
}
