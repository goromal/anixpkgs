final: prev: 
with prev.lib;
let
    pkgSources = import ../sources.nix;
    minJDK = prev.jdk11_headless;
    minJRE = prev.jre_minimal.override {
        jdk = minJDK;
        modules = [
            "java.base"
            "java.logging"
        ];
    };
    baseJavaArgs = {
        jdk = minJDK;
        jre = minJRE;
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
            gmail-parser = pySelf.callPackage ./python-packages/gmail-parser { pkg-src = pkgSources.gmail-parser; };
            sunnyside = pySelf.callPackage ./python-packages/sunnyside { };
            find_rotational_conventions = pySelf.callPackage ./python-packages/find_rotational_conventions { pkg-src = pkgSources.find_rotational_conventions; };
            geometry = pySelf.callPackage ./python-packages/geometry { pkg-src = pkgSources.geometry; };
            pyceres = pySelf.callPackage ./python-packages/pyceres { pkg-src = pkgSources.pyceres; };
            pyceres_factors = pySelf.callPackage ./python-packages/pyceres_factors { pkg-src = pkgSources.pyceres_factors; };
            pysignals = pySelf.callPackage ./python-packages/pysignals { pkg-src = pkgSources.pysignals; };
            mesh-plotter = pySelf.callPackage ./python-packages/mesh-plotter { pkg-src = pkgSources.mesh-plotter; };
            makepyshell = pySelf.callPackage ./python-packages/makepyshell { pkg-src = pkgSources.makepyshell; };
            norbert = pySelf.callPackage ./python-packages/norbert { };
            scrape = pySelf.callPackage ./python-packages/scrape { pkg-src = pkgSources.scrape; };
            spleeter = pySelf.callPackage ./python-packages/spleeter { };
            trafficsim = pySelf.callPackage ./python-packages/trafficsim { pkg-src = pkgSources.trafficsim; };
            ichabod = pySelf.callPackage ./python-packages/ichabod { };
            imutils-cv4 = pySelf.callPackage ./python-packages/imutils-cv4 { };
            vidstab-cv4 = pySelf.callPackage ./python-packages/vidstab-cv4 { };
            flask-hello-world = pySelf.callPackage ./python-packages/flasks/hello-world { };
            flask-url2mp4 = pySelf.callPackage ./python-packages/flasks/url2mp4 { wget-pkg = prev.wget; };
            flask-mp4server = pySelf.callPackage ./python-packages/flasks/mp4server { };
            flask-mp3server = pySelf.callPackage ./python-packages/flasks/mp3server { };
            flask-smfserver = pySelf.callPackage ./python-packages/flasks/smfserver { };
        });
    }));
in {
    strings = prev.callPackage ./bash-packages/bash-utils/strings.nix { };
    redirects = prev.callPackage ./bash-packages/bash-utils/redirects.nix { };
    color-prints = prev.callPackage ./bash-packages/color-prints { };
    cpp-helper = prev.callPackage ./bash-packages/cpp-helper { };
    git-cc = prev.callPackage ./bash-packages/git-cc { };
    md2pdf = prev.callPackage ./bash-packages/converters/md2pdf.nix { };
    mp4unite = prev.callPackage ./bash-packages/mp4unite { };
    notabilify = prev.callPackage ./bash-packages/converters/notabilify.nix { };
    make-title = prev.callPackage ./bash-packages/make-title { };
    pb = prev.callPackage ./bash-packages/pb { };
    code2pdf = prev.callPackage ./bash-packages/converters/code2pdf.nix { };
    abc = prev.callPackage ./bash-packages/converters/abc.nix { };
    doku = prev.callPackage ./bash-packages/converters/doku.nix { };
    epub = prev.callPackage ./bash-packages/converters/epub.nix { };
    gif = prev.callPackage ./bash-packages/converters/gif.nix { };
    html = prev.callPackage ./bash-packages/converters/html.nix { };
    md = prev.callPackage ./bash-packages/converters/md.nix { };
    mp3 = prev.callPackage ./bash-packages/converters/mp3.nix { };
    mp4 = prev.callPackage ./bash-packages/converters/mp4.nix { };
    pdf = prev.callPackage ./bash-packages/converters/pdf.nix { };
    png = prev.callPackage ./bash-packages/converters/png.nix { };
    svg = prev.callPackage ./bash-packages/converters/svg.nix { scour = prev.python38.pkgs.scour; };
    zipper = prev.callPackage ./bash-packages/converters/zipper.nix { };
    fix-perms = prev.callPackage ./bash-packages/fix-perms { };

    manif-geom-cpp = prev.callPackage ./cxx-packages/manif-geom-cpp { pkg-src = pkgSources.manif-geom-cpp; };
    ceres-factors = prev.callPackage ./cxx-packages/ceres-factors { pkg-src = pkgSources.ceres-factors; };
    signals-cpp = prev.callPackage ./cxx-packages/signals-cpp { pkg-src = pkgSources.signals-cpp; };
    secure-delete = prev.callPackage ./cxx-packages/secure-delete { pkg-src = pkgSources.secure-delete; };

    evil-hangman = prev.callPackage ./java-packages/evil-hangman (baseJavaArgs // { pkg-src = pkgSources.evil-hangman; });
    spelling-corrector = prev.callPackage ./java-packages/spelling-corrector (baseJavaArgs // { pkg-src = pkgSources.spelling-corrector; });
    simple-image-editor = prev.callPackage ./java-packages/simple-image-editor (baseJavaArgs // { pkg-src = pkgSources.simple-image-editor; });

    python27 = pythonOverridesFor prev.python27;
    python37 = pythonOverridesFor prev.python37;
    python38 = pythonOverridesFor prev.python38;
    python39 = pythonOverridesFor prev.python39;
    python310 = pythonOverridesFor prev.python310;
 
    makepyshell = final.python38.pkgs.makepyshell;
    sunnyside = final.python38.pkgs.sunnyside;
    scrape = final.python38.pkgs.scrape;
    spleeter = final.python38.pkgs.spleeter;
    find_rotational_conventions = final.python38.pkgs.find_rotational_conventions;
    trafficsim = final.python38.pkgs.trafficsim;
    flask-hello-world = final.python38.pkgs.flask-hello-world;
    flask-url2mp4 = final.python38.pkgs.flask-url2mp4;
    flask-mp4server = final.python38.pkgs.flask-mp4server;
    flask-mp3server = final.python38.pkgs.flask-mp3server;
    flask-smfserver = final.python38.pkgs.flask-smfserver;

    manage-gmail = prev.callPackage ./bash-packages/manage-gmail { python = final.python38; };

    xv-lidar-rs = prev.callPackage ./rust-packages/xv-lidar-rs { pkg-src = pkgSources.xv-lidar-rs; };

    aerowake = prev.callPackage ./ros-packages/aerowake { rosDistro = prev.rosPackages.noetic; };

    nixos-machines = rec {
        personal = makeMachines "personal";
    };
    run-sitl-machine = prev.callPackage ./bash-packages/run-sitl {
        writeShellScriptBin = prev.writeShellScriptBin;
        callPackage = prev.callPackage;
        color-prints = prev.callPackage ./bash-packages/color-prints {};
        machines = [
            { name = "personal"; description = "Personal Linux machine for the day-to-day."; }
        ];
    };

    multirotor-sim = prev.callPackage ./nixos/multirotor/run.nix baseModuleArgs;
}
