final: prev: 
with prev.lib;
let
    pythonOverridesFor = superPython: fix (python: superPython.override ({
        packageOverrides ? _: _: {}, ...
    }: {
        self = python;
        packageOverrides = composeExtensions packageOverrides (pySelf: pySuper: {
            # bson = pySelf.callPackage ./bson { };
        });
    }));
in {
    abcm2ps = prev.callPackage ./cxx-packages/abcm2ps {
        stdenv = prev.clangStdenv;
    };
    abcmidi = prev.callPackage ./cxx-packages/abcmidi {
        stdenv = prev.clangStdenv;
    };
    
    # python27 = pythonOverridesFor super.python27;
    # python37 = pythonOverridesFor super.python37;
    # python38 = pythonOverridesFor super.python38;
    # python39 = pythonOverridesFor super.python39;
    # python310 = pythonOverridesFor super.python310;
}
