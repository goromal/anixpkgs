final: prev: 
with prev.lib;
let
    pythonOverridesFor = superPython: fix (python: superPython.override ({
        packageOverrides ? _: _: {}, ...
    }: {
        self = python;
        packageOverrides = composeExtensions packageOverrides (pySelf: pySuper: {
            norbert = pySelf.callPackage ./python-packages/norbert {
                buildPythonPackage = pySelf.buildPythonPackage;
                fetchPypi = pySelf.fetchPypi;
                pythonOlder = pySelf.pythonOlder;
                scipy = python.pkgs.scipy;
            };
            spleeter = pySelf.callPackage ./python-packages/spleeter {
                buildPythonPackage = pySelf.buildPythonPackage;
                callPackage = pySelf.callPackage;
                fetchPypi = pySelf.fetchPypi;
                isPyPy = pySelf.isPyPy;
                pythonOlder = pySelf.pythonOlder;
                inherit python;
                stdenv = prev.clangStdenv;
                lib = prev.lib;
                pytestCheckHook = pySelf.pytestCheckHook;
                pytest-xdist = pySelf.pytest-xdist;
                shellingham = pySelf.shellingham;
                coverage = pySelf.coverage;
                mypy = pySelf.pkgs.mypy;
                black = pySelf.pkgs.black;
                isort = pySelf.isort;
                locale = prev.locale;
                pandas = python.pkgs.pandas;
                tensorflow = python.pkgs.tensorflow;
                ffmpeg = prev.ffmpeg;
                libsndfile = prev.libsndfile;
                llvm = prev.llvm_9;
                enum34 = prev.enum34;
                isPy3k = pySelf.isPy3k;
                ffmpeg-python = python.pkgs.ffmpeg-python;
                norbert = python.pkgs.norbert;
                gfortran = prev.gfortran;
                pytest = python.pkgs.pytest;
                blas = prev.blas;
                lapack = prev.lapack;
                writeTextFile = prev.writeTextFile;
                cython = python.pkgs.cython;
                setuptoolsBuildHook = pySelf.setuptoolsBuildHook;
                scipy = python.pkgs.scipy;
                tensorflow-tensorboard = python.pkgs.tensorflow-tensorboard;
                tensorflow-estimator = python.pkgs.tensorflow-estimator;
                h5py = python.pkgs.h5py;
                opt-einsum = python.pkgs.opt-einsum;
                keras = python.pkgs.keras;
                keras-preprocessing = python.pkgs.keras-preprocessing;
                pillow = python.pkgs.pillow;
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
