final: prev: 
with prev.lib;
let
    pythonOverridesFor = superPython: fix (python: superPython.override ({
        packageOverrides ? _: _: {}, ...
    }: {
        self = python;
        packageOverrides = composeExtensions packageOverrides (pySelf: pySuper: {
            spleeter = pySelf.callPackage ./python-packages/spleeter {
                buildPythonPackage = self.buildPythonPackage;
                fetchPypi = self.fetchPypi;
                ffmpeg = prev.ffmpeg;
                libsndfile = prev.libsndfile;
            };
        });
    }));
in {
    manif-geom-cpp = prev.callPackage ./cxx-packages/manif-geom-cpp {
        stdenv = prev.clangStdenv;
        eigen = prev.eigen;
        boost = prev.boost;
    };
    
    python27 = pythonOverridesFor super.python27;
    python37 = pythonOverridesFor super.python37;
    python38 = pythonOverridesFor super.python38;
    python39 = pythonOverridesFor super.python39;
    python310 = pythonOverridesFor super.python310;
}
