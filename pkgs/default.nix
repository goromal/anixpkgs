final: prev:
with prev.lib;
let
  flakeInputs = final.flakeInputs;
  service-ports = import ./nixos/service-ports.nix;
  aapis-fds = prev.stdenvNoCC.mkDerivation {
    name = "aapis-fds";
    nativeBuildInputs = [ prev.protobuf ];
    src = "${flakeInputs.aapis}/protos";
    buildPhase = ''
      includes=$(find ${prev.protobuf}/include/google/protobuf/*.proto)
      files=$(find -name '*.proto')
      protoc -I ${prev.protobuf}/include -I ./. --descriptor_set_out=./aapis.protoset $files $includes
    '';
    installPhase = ''
      mv aapis.protoset $out  
    '';
  };

  addDoc = pkg-attr:
    pkg-attr // rec {
      doc = prev.writeTextFile {
        name = "doc.txt";
        text = (if builtins.hasAttr "description" pkg-attr.meta then ''
          ${pkg-attr.meta.description}

          ${pkg-attr.meta.longDescription}
        '' else ''
          No package documentation currently provided.
        '');
      };
    };

  minJDK = prev.jdk11_headless;
  minJRE = prev.jre_minimal.override {
    jdk = minJDK;
    modules = [ "java.base" "java.logging" ];
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

  pythonOverridesFor = superPython:
    fix (python:
      superPython.override ({ packageOverrides ? _: _: { }, ... }: {
        self = python;
        packageOverrides = composeExtensions packageOverrides
          (pySelf: pySuper: {
            aapis-py = addDoc (pySelf.callPackage ./python-packages/aapis-py {
              apis-fds = aapis-fds;
              pkg-src = flakeInputs.aapis;
            });
            authm = addDoc (pySelf.callPackage ./python-packages/authm { });
            budget_report =
              addDoc (pySelf.callPackage ./python-packages/budget-report { });
            easy-google-auth = addDoc
              (pySelf.callPackage ./python-packages/easy-google-auth {
                pkg-src = flakeInputs.easy-google-auth;
              });
            gmail-parser = addDoc
              (pySelf.callPackage ./python-packages/gmail-parser {
                pkg-src = flakeInputs.gmail-parser;
              });
            goromail =
              addDoc (pySelf.callPackage ./python-packages/goromail { });
            sunnyside =
              addDoc (pySelf.callPackage ./python-packages/sunnyside { });
            fqt = addDoc (pySelf.callPackage ./python-packages/fqt { });
            find_rotational_conventions = addDoc (pySelf.callPackage
              ./python-packages/find_rotational_conventions {
                pkg-src = flakeInputs.find_rotational_conventions;
              });
            geometry = addDoc (pySelf.callPackage ./python-packages/geometry {
              pkg-src = flakeInputs.geometry;
            });
            pyceres = addDoc (pySelf.callPackage ./python-packages/pyceres {
              pkg-src = flakeInputs.pyceres;
            });
            pyceres_factors = addDoc
              (pySelf.callPackage ./python-packages/pyceres_factors {
                pkg-src = flakeInputs.pyceres_factors;
              });
            pysignals = addDoc (pySelf.callPackage ./python-packages/pysignals {
              pkg-src = flakeInputs.pysignals;
            });
            pysorting = addDoc (pySelf.callPackage ./python-packages/pysorting {
              pkg-src = flakeInputs.pysorting;
            });
            python-dokuwiki = addDoc
              (pySelf.callPackage ./python-packages/python-dokuwiki {
                pkg-src = flakeInputs.python-dokuwiki;
              });
            book-notes-sync = addDoc
              (pySelf.callPackage ./python-packages/book-notes-sync {
                pkg-src = flakeInputs.book-notes-sync;
              });
            task-tools = addDoc
              (pySelf.callPackage ./python-packages/task-tools {
                pkg-src = flakeInputs.task-tools;
              });
            wiki-tools = addDoc
              (pySelf.callPackage ./python-packages/wiki-tools {
                pkg-src = flakeInputs.wiki-tools;
              });
            mavlog-utils = addDoc
              (pySelf.callPackage ./python-packages/mavlog-utils {
                pkg-src = flakeInputs.mavlog-utils;
              });
            mesh-plotter = addDoc
              (pySelf.callPackage ./python-packages/mesh-plotter {
                pkg-src = flakeInputs.mesh-plotter;
              });
            makepyshell = addDoc
              (pySelf.callPackage ./python-packages/makepyshell {
                pkg-src = flakeInputs.makepyshell;
              });
            norbert = addDoc (pySelf.callPackage ./python-packages/norbert { });
            orchestrator = addDoc
              (pySelf.callPackage ./python-packages/orchestrator {
                mp4 = final.mp4;
                mp4unite = final.mp4;
                scrape = final.scrape;
                inherit service-ports;
                pkg-src = flakeInputs.orchestrator;
              });
            scrape = addDoc (pySelf.callPackage ./python-packages/scrape {
              pkg-src = flakeInputs.scrape;
            });
            spleeter =
              addDoc (pySelf.callPackage ./python-packages/spleeter { });
            trafficsim = addDoc
              (pySelf.callPackage ./python-packages/trafficsim {
                pkg-src = flakeInputs.trafficsim;
              });
            ichabod = addDoc (pySelf.callPackage ./python-packages/ichabod { });
            imutils-cv4 =
              addDoc (pySelf.callPackage ./python-packages/imutils-cv4 { });
            vidstab-cv4 =
              addDoc (pySelf.callPackage ./python-packages/vidstab-cv4 { });
            rich = addDoc (pySelf.callPackage ./python-packages/rich { });
            syrupy = addDoc (pySelf.callPackage ./python-packages/syrupy { });
            # textual = addDoc (pySelf.callPackage ./python-packages/textual { });
            flask-hello-world = addDoc
              (pySelf.callPackage ./python-packages/flasks/hello-world { });
            flask-url2mp4 = addDoc
              (pySelf.callPackage ./python-packages/flasks/url2mp4 {
                wget-pkg = prev.wget;
              });
            flask-mp4server = addDoc
              (pySelf.callPackage ./python-packages/flasks/mp4server { });
            flask-mp3server = addDoc
              (pySelf.callPackage ./python-packages/flasks/mp3server { });
            flask-smfserver = addDoc
              (pySelf.callPackage ./python-packages/flasks/smfserver { });
            flask-oatbox =
              addDoc (pySelf.callPackage ./python-packages/flasks/oatbox { });
            rankserver = addDoc
              (pySelf.callPackage ./python-packages/flasks/rankserver { });
          });
      }));
in rec {
  pkgsSource = { local ? false, rev ? null, ref ? null }:
    prev.stdenvNoCC.mkDerivation {
      name = "anixpkgs-src";
      src = if rev == null then
        (builtins.fetchTarball
          "https://github.com/goromal/anixpkgs/archive/${ref}.tar.gz")
      else
        (builtins.fetchGit {
          url = "https://github.com/goromal/anixpkgs";
          inherit rev;
          allRefs = true;
        });
      nativeBuildInputs = [ prev.git ];
      buildPhase = (if local then ''
        sed -i 's|local-build = false;|local-build = true;|g' "pkgs/nixos/dependencies.nix"
      '' else
        "");
      installPhase = ''
        mkdir -p $out
        cp -r * $out/
      '';
    };
  pkgData = prev.callPackage flakeInputs.anixdata { };

  python38 = pythonOverridesFor prev.python38;
  python39 = pythonOverridesFor prev.python39;
  python310 = pythonOverridesFor prev.python310;
  python311 = pythonOverridesFor prev.python311;

  budget_report = final.python39.pkgs.budget_report;
  makepyshell = final.python39.pkgs.makepyshell;
  mavlog-utils = final.python39.pkgs.mavlog-utils;
  sunnyside = final.python39.pkgs.sunnyside;
  fqt = final.python39.pkgs.fqt;
  scrape = final.python39.pkgs.scrape;
  spleeter = final.python39.pkgs.spleeter;
  find_rotational_conventions = final.python39.pkgs.find_rotational_conventions;
  trafficsim = final.python39.pkgs.trafficsim;
  flask-hello-world = final.python39.pkgs.flask-hello-world;
  flask-url2mp4 = final.python39.pkgs.flask-url2mp4;
  flask-mp4server = final.python39.pkgs.flask-mp4server;
  flask-mp3server = final.python39.pkgs.flask-mp3server;
  flask-smfserver = final.python39.pkgs.flask-smfserver;
  flask-oatbox = final.python39.pkgs.flask-oatbox;
  rankserver = final.python39.pkgs.rankserver;
  task-tools = final.python310.pkgs.task-tools;
  wiki-tools = final.python310.pkgs.wiki-tools;
  book-notes-sync = final.python310.pkgs.book-notes-sync;
  gmail-parser = final.python310.pkgs.gmail-parser;
  authm = final.python310.pkgs.authm;
  goromail = final.python310.pkgs.goromail;
  orchestrator = final.python39.pkgs.orchestrator;

  manage-gmail = addDoc (prev.callPackage ./bash-packages/manage-gmail {
    python = final.python310;
  });
  gantter = addDoc (prev.callPackage ./bash-packages/gantter {
    python = final.python39;
    blank-svg = pkgData.img.blank-svg;
  });
  la-quiz = addDoc
    (prev.callPackage ./bash-packages/la-quiz { python = final.python39; });

  aapis-grpcurl = addDoc
    (prev.callPackage ./bash-packages/aapis-grpcurl { apis-fds = aapis-fds; });
  strings =
    addDoc (prev.callPackage ./bash-packages/bash-utils/strings.nix { });
  redirects =
    addDoc (prev.callPackage ./bash-packages/bash-utils/redirects.nix { });
  color-prints = addDoc (prev.callPackage ./bash-packages/color-prints { });
  cpp-helper = addDoc (prev.callPackage ./bash-packages/cpp-helper { });
  py-helper = addDoc (prev.callPackage ./bash-packages/py-helper { });
  dirgroups = addDoc (prev.callPackage ./bash-packages/dirgroups { });
  git-cc = addDoc (prev.callPackage ./bash-packages/git-cc { });
  gitcop = addDoc (prev.callPackage ./bash-packages/gitcop { });
  md2pdf = addDoc (prev.callPackage ./bash-packages/converters/md2pdf.nix { });
  mp4unite = addDoc (prev.callPackage ./bash-packages/mp4unite { });
  notabilify =
    addDoc (prev.callPackage ./bash-packages/converters/notabilify.nix { });
  make-title = addDoc (prev.callPackage ./bash-packages/make-title { });
  pb = addDoc (prev.callPackage ./bash-packages/pb { });
  code2pdf =
    addDoc (prev.callPackage ./bash-packages/converters/code2pdf.nix { });
  abc = addDoc (prev.callPackage ./bash-packages/converters/abc.nix { });
  doku = addDoc (prev.callPackage ./bash-packages/converters/doku.nix { });
  epub = addDoc (prev.callPackage ./bash-packages/converters/epub.nix { });
  gif = addDoc (prev.callPackage ./bash-packages/converters/gif.nix { });
  md = addDoc (prev.callPackage ./bash-packages/converters/md.nix { });
  mp3 = addDoc (prev.callPackage ./bash-packages/converters/mp3.nix { });
  mp4 = addDoc (prev.callPackage ./bash-packages/converters/mp4.nix { });
  pdf = addDoc (prev.callPackage ./bash-packages/converters/pdf.nix { });
  png = addDoc (prev.callPackage ./bash-packages/converters/png.nix { });
  svg = addDoc (prev.callPackage ./bash-packages/converters/svg.nix {
    scour = final.python39.pkgs.scour;
  });
  zipper = addDoc (prev.callPackage ./bash-packages/converters/zipper.nix { });
  fix-perms = addDoc (prev.callPackage ./bash-packages/fix-perms { });
  setupws = addDoc (prev.callPackage ./bash-packages/setupws { });
  listsources = addDoc (prev.callPackage ./bash-packages/listsources { });
  pkgshell = addDoc (prev.callPackage ./bash-packages/pkgshell { });
  devshell = addDoc (prev.callPackage ./bash-packages/devshell { });
  providence = addDoc (prev.callPackage ./bash-packages/providence { });
  providence-tasker =
    addDoc (prev.callPackage ./bash-packages/providence/tasker.nix { });
  fixfname = addDoc (prev.callPackage ./bash-packages/fixfname { });
  cloud-manager = addDoc (prev.callPackage ./bash-packages/cloud-manager { });
  nix-deps =
    addDoc (prev.callPackage ./bash-packages/nix-tools/nix-deps.nix { });
  nix-diffs =
    addDoc (prev.callPackage ./bash-packages/nix-tools/nix-diffs.nix { });
  anix-version =
    addDoc (prev.callPackage ./bash-packages/nix-tools/anix-version.nix { });
  anix-upgrade =
    addDoc (prev.callPackage ./bash-packages/nix-tools/anix-upgrade.nix { });

  aapis-cpp = addDoc (prev.callPackage ./cxx-packages/aapis-cpp {
    pkg-src = flakeInputs.aapis;
  });
  manif-geom-cpp = addDoc (prev.callPackage ./cxx-packages/manif-geom-cpp {
    pkg-src = flakeInputs.manif-geom-cpp;
  });
  quad-sim-cpp = addDoc (prev.callPackage ./cxx-packages/quad-sim-cpp {
    pkg-src = flakeInputs.quad-sim-cpp;
  });
  mscpp = addDoc
    (prev.callPackage ./cxx-packages/mscpp { pkg-src = flakeInputs.mscpp; });
  ceres-factors = addDoc (prev.callPackage ./cxx-packages/ceres-factors {
    pkg-src = flakeInputs.ceres-factors;
  });
  signals-cpp = addDoc (prev.callPackage ./cxx-packages/signals-cpp {
    pkg-src = flakeInputs.signals-cpp;
  });
  secure-delete = addDoc (prev.callPackage ./cxx-packages/secure-delete {
    pkg-src = flakeInputs.secure-delete;
  });
  sorting = addDoc (prev.callPackage ./cxx-packages/sorting {
    pkg-src = flakeInputs.sorting;
  });
  rankserver-cpp = addDoc (prev.callPackage ./cxx-packages/rankserver-cpp {
    pkg-src = flakeInputs.rankserver-cpp;
  });
  crowcpp = addDoc (prev.callPackage ./cxx-packages/crowcpp {
    pkg-src = flakeInputs.crowcpp;
  });
  mfn = addDoc (prev.callPackage ./cxx-packages/mfn {
    pkg-src = flakeInputs.mfn;
    model-proto = pkgData.models.gender.proto.data;
    model-weights = pkgData.models.gender.weights.data;
  });

  evil-hangman = addDoc (prev.callPackage ./java-packages/evil-hangman
    (baseJavaArgs // { pkg-src = flakeInputs.evil-hangman; }));
  spelling-corrector = addDoc
    (prev.callPackage ./java-packages/spelling-corrector
      (baseJavaArgs // { pkg-src = flakeInputs.spelling-corrector; }));
  simple-image-editor = addDoc
    (prev.callPackage ./java-packages/simple-image-editor
      (baseJavaArgs // { pkg-src = flakeInputs.simple-image-editor; }));

  manif-geom-rs = addDoc (prev.callPackage ./rust-packages/manif-geom-rs {
    pkg-src = flakeInputs.manif-geom-rs;
  });
  xv-lidar-rs = addDoc (prev.callPackage ./rust-packages/xv-lidar-rs {
    pkg-src = flakeInputs.xv-lidar-rs;
  });

  nixos-machines = rec { personal = makeMachines "personal"; };
  run-sitl-machine = prev.callPackage ./bash-packages/run-sitl {
    writeShellScriptBin = prev.writeShellScriptBin;
    callPackage = prev.callPackage;
    color-prints = prev.callPackage ./bash-packages/color-prints { };
    machines = [{
      name = "personal";
      description = "Personal Linux machine for the day-to-day.";
    }];
  };

  multirotor-sim = prev.callPackage ./nixos/multirotor/run.nix baseModuleArgs;
}
