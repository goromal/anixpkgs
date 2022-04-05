final: prev: 
with prev.lib;
let
    minJDK = prev.jdk11_headless;
    minJRE = prev.jre_minimal.override {
        jdk = minJDK;
        modules = [
            "java.base"
            "java.logging"
        ];
    };
    baseJavaArgs = {
        stdenv = prev.stdenv;
        jdk = minJDK;
        jre = minJRE;
        ant = prev.ant;
        makeWrapper = prev.makeWrapper;
    };

    baseConvArgs = {
        writeShellScriptBin = prev.writeShellScriptBin;
        callPackage = prev.callPackage;
        color-prints = prev.callPackage ./bash-packages/color-prints {};
        strings = prev.callPackage ./bash-packages/bash-utils/strings.nix {
            writeShellScript = prev.writeShellScript;
        };
        redirects = prev.callPackage ./bash-packages/bash-utils/redirects.nix {};
    };

    baseModuleArgs = {
        pkgs = final;
        config = final.config;
        lib = final.lib;
    };

    makeMachines = name: {
        sitl = import (./nixos + (("/" + name) + "/sitl.nix")) baseModuleArgs;
        # TODO add list arg for hardware names
    };

    pythonOverridesFor = superPython: fix (python: superPython.override ({
        packageOverrides ? _: _: {}, ...
    }: {
        self = python;
        packageOverrides = composeExtensions packageOverrides (pySelf: pySuper: {
            sunnyside = pySelf.callPackage ./python-packages/sunnyside {
                callPackage = prev.callPackage;
                pytestCheckHook = pySelf.pytestCheckHook;
                buildPythonPackage = pySelf.buildPythonPackage;
            };
            geometry = pySelf.callPackage ./python-packages/geometry {
                callPackage = prev.callPackage;
                stdenv = prev.clangStdenv;
                cmake = prev.cmake;
                manif-geom-cpp = final.manif-geom-cpp;
                eigen = prev.eigen;
                numpy = python.pkgs.numpy;
                pybind11 = python.pkgs.pybind11;
                inherit python;
                pythonOlder = pySelf.pythonOlder;
                pytestCheckHook = pySelf.pytestCheckHook;
                buildPythonPackage = pySelf.buildPythonPackage;
            };
            pyceres = pySelf.callPackage ./python-packages/pyceres {
                callPackage = prev.callPackage;
                stdenv = prev.clangStdenv;
                cmake = prev.cmake;
                ceres = prev.ceres-solver;
                eigen = prev.eigen;
                glog = prev.glog;
                gflags = prev.gflags;
                suitesparse = prev.suitesparse;
                pybind11 = python.pkgs.pybind11;
                inherit python;
                pythonOlder = pySelf.pythonOlder;
                pytestCheckHook = pySelf.pytestCheckHook;
                buildPythonPackage = pySelf.buildPythonPackage;
            };
            pyceres_factors = pySelf.callPackage ./python-packages/pyceres_factors {
                callPackage = prev.callPackage;
                stdenv = prev.clangStdenv;
                cmake = prev.cmake;
                ceres = prev.ceres-solver;
                ceres-factors = final.ceres-factors;
                manif-geom-cpp = final.manif-geom-cpp;
                eigen = prev.eigen;
                numpy = python.pkgs.numpy;
                geometry = python.pkgs.geometry;
                pyceres = python.pkgs.pyceres;
                pybind11 = python.pkgs.pybind11;
                inherit python;
                pythonOlder = pySelf.pythonOlder;
                pytestCheckHook = pySelf.pytestCheckHook;
                buildPythonPackage = pySelf.buildPythonPackage;
            };
            pysignals = pySelf.callPackage ./python-packages/pysignals {
                callPackage = prev.callPackage;
                stdenv = prev.clangStdenv;
                cmake = prev.cmake;
                signals-cpp = final.signals-cpp;
                eigen = prev.eigen;
                pybind11 = python.pkgs.pybind11;
                inherit python;
                pythonOlder = pySelf.pythonOlder;
                pytestCheckHook = pySelf.pytestCheckHook;
                buildPythonPackage = pySelf.buildPythonPackage;
                numpy = python.pkgs.numpy;
                geometry = python.pkgs.geometry;
            };
            mesh-plotter = pySelf.callPackage ./python-packages/mesh-plotter {
                buildPythonPackage = pySelf.buildPythonPackage;
                fetchPypi = pySelf.fetchPypi;
                pythonOlder = pySelf.pythonOlder;
                numpy = python.pkgs.numpy;
                matplotlib = python.pkgs.matplotlib;
                geometry = python.pkgs.geometry;
                pysignals = python.pkgs.pysignals;
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
                pythonAtLeast = pySelf.pythonAtLeast;
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
            ichabod = pySelf.callPackage ./python-packages/ichabod {
                callPackage = prev.callPackage;
                pytestCheckHook = pySelf.pytestCheckHook;
                buildPythonPackage = pySelf.buildPythonPackage;
                pystemd = python.pkgs.pystemd;
                veryprettytable = python.pkgs.veryprettytable;
            };
        });
    }));
in {
    abc = prev.callPackage ./bash-packages/converters/abc.nix (baseConvArgs // {
       abcmidi = prev.abcmidi;
    });
    doku = prev.callPackage ./bash-packages/converters/doku.nix (baseConvArgs // {

    });
    epub = prev.callPackage ./bash-packages/converters/epub.nix (baseConvArgs // {

    });
    gif = prev.callPackage ./bash-packages/converters/gif.nix (baseConvArgs // {

    });
    html = prev.callPackage ./bash-packages/converters/html.nix (baseConvArgs // {

    });
    md = prev.callPackage ./bash-packages/converters/md.nix (baseConvArgs // {

    });
    midi = prev.callPackage ./bash-packages/converters/midi.nix (baseConvArgs // {

    });
    mp3 = prev.callPackage ./bash-packages/converters/mp3.nix (baseConvArgs // {
        
    });
    mp4 = prev.callPackage ./bash-packages/converters/mp4.nix (baseConvArgs // {

    });
    pdf = prev.callPackage ./bash-packages/converters/pdf.nix (baseConvArgs // {

    });
    png = prev.callPackage ./bash-packages/converters/png.nix (baseConvArgs // {

    });
    svg = prev.callPackage ./bash-packages/converters/svg.nix (baseConvArgs // {
       inkscape = prev.inkscape;
       abcm2ps = prev.abcm2ps;
       scour = prev.python38.pkgs.scour;
    });
    zipper = prev.callPackage ./bash-packages/converters/zipper.nix (baseConvArgs // {

    });

    color-prints = prev.callPackage ./bash-packages/color-prints {
        stdenv = prev.stdenv;
        writeShellScriptBin = prev.writeShellScriptBin;
    };

    manif-geom-cpp = prev.callPackage ./cxx-packages/manif-geom-cpp {
        stdenv = prev.clangStdenv;
        cmake = prev.cmake;
        eigen = prev.eigen;
        boost = prev.boost;
    };
    ceres-factors = prev.callPackage ./cxx-packages/ceres-factors {
        stdenv = prev.clangStdenv;
        cmake = prev.cmake;
        eigen = prev.eigen;
        ceres = prev.ceres-solver;
        manif-geom-cpp = final.manif-geom-cpp;
        boost = prev.boost;
    };
    signals-cpp = prev.callPackage ./cxx-packages/signals-cpp {
        stdenv = prev.clangStdenv;
        cmake = prev.cmake;
        eigen = prev.eigen;
        manif-geom-cpp = final.manif-geom-cpp;
        boost = prev.boost;
    };

    evil-hangman = prev.callPackage ./java-packages/evil-hangman baseJavaArgs;
    spelling-corrector = prev.callPackage ./java-packages/spelling-corrector baseJavaArgs;
    simple-image-editor = prev.callPackage ./java-packages/simple-image-editor baseJavaArgs;

    python27 = pythonOverridesFor prev.python27;
    python37 = pythonOverridesFor prev.python37;
    python38 = pythonOverridesFor prev.python38;
    python39 = pythonOverridesFor prev.python39;
    python310 = pythonOverridesFor prev.python310;
    
    sunnyside = final.python38.pkgs.sunnyside;
    spleeter = final.python38.pkgs.spleeter;

    nixos-machines = rec {
        minimal = makeMachines "minimal";
        base = makeMachines "base";
        personal = makeMachines "personal";
    };
    run-sitl-machine = prev.callPackage ./bash-packages/run-sitl {
        writeShellScriptBin = prev.writeShellScriptBin;
        callPackage = prev.callPackage;
        color-prints = prev.callPackage ./bash-packages/color-prints {};
        machines = [
            { name = "minimal"; description = "Just the latest Linux kernel, and nothing else."; }
            { name = "base"; description = "Machine wrapper around all common processes and programs."; }
            { name = "personal"; description = "Personal Linux machine for the day-to-day."; }
        ];
    };
}
