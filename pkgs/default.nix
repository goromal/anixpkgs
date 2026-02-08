final: prev:
with prev.lib;
let
  flakeInputs = final.flakeInputs;
  anixpkgs-version = (builtins.readFile ../ANIX_VERSION);
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

  addDoc =
    pkg-attr:
    let
      # TODO: maybe remove the (Auto-Generated) qualifier when the functionality has proven out
      sub-cmds = if builtins.hasAttr "subCmds" pkg-attr.meta then pkg-attr.meta.subCmds else [ ];
      auto-usage-doc = (
        if builtins.hasAttr "autoGenUsageCmd" pkg-attr.meta then
          (
            if pkg-attr.meta.autoGenUsageCmd != null then
              ''

                ## Usage

                ${prev.callPackage ./bash-packages/bash-utils/genusagedoc.nix {
                  packageAttr = pkg-attr;
                  helpCmd = pkg-attr.meta.autoGenUsageCmd;
                  subCmds = sub-cmds;
                }}
              ''
            else
              ""
          )
        else
          ""
      );
    in
    pkg-attr
    // rec {
      doc = prev.writeTextFile {
        name = "doc.txt";
        text = (
          if builtins.hasAttr "description" pkg-attr.meta then
            (''
              ${pkg-attr.meta.description}

              ${pkg-attr.meta.longDescription}${auto-usage-doc}
            '')
          else
            ''
              No package documentation currently provided.
            ''
        );
      };
    };

  minJRE = prev.jre_minimal.override {
    modules = [
      "java.base"
      "java.logging"
    ];
  };
  baseJavaArgs = {
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

  pythonOverridesFor =
    superPython:
    fix (
      python:
      superPython.override (
        {
          packageOverrides ? _: _: { },
          ...
        }:
        {
          self = python;
          packageOverrides = composeExtensions packageOverrides (
            pySelf: pySuper: {
              aapis-py = addDoc (
                pySelf.callPackage ./python-packages/aapis-py {
                  apis-fds = aapis-fds;
                  pkg-src = flakeInputs.aapis;
                }
              );
              budget_report = addDoc (pySelf.callPackage ./python-packages/budget-report { });
              surveys_report = addDoc (pySelf.callPackage ./python-packages/surveys-report { });
              easy-google-auth = addDoc (
                pySelf.callPackage ./python-packages/easy-google-auth {
                  pkg-src = flakeInputs.easy-google-auth;
                }
              );
              gmail-parser = addDoc (
                pySelf.callPackage ./python-packages/gmail-parser {
                  pkg-src = flakeInputs.gmail-parser;
                }
              );
              goromail = addDoc (pySelf.callPackage ./python-packages/goromail { });
              symforce = addDoc (pySelf.callPackage ./python-packages/symforce { });
              fqt = addDoc (pySelf.callPackage ./python-packages/fqt { });
              find_rotational_conventions = addDoc (
                pySelf.callPackage ./python-packages/find_rotational_conventions {
                  pkg-src = flakeInputs.find_rotational_conventions;
                }
              );
              geometry = addDoc (
                pySelf.callPackage ./python-packages/geometry {
                  pkg-src = flakeInputs.geometry;
                }
              );
              pyceres = addDoc (
                pySelf.callPackage ./python-packages/pyceres {
                  pkg-src = flakeInputs.pyceres;
                }
              );
              pyceres_factors = addDoc (
                pySelf.callPackage ./python-packages/pyceres_factors {
                  pkg-src = flakeInputs.pyceres_factors;
                }
              );
              pysignals = addDoc (
                pySelf.callPackage ./python-packages/pysignals {
                  pkg-src = flakeInputs.pysignals;
                }
              );
              pysorting = addDoc (
                pySelf.callPackage ./python-packages/pysorting {
                  pkg-src = flakeInputs.pysorting;
                }
              );
              python-dokuwiki = addDoc (
                pySelf.callPackage ./python-packages/python-dokuwiki {
                  pkg-src = flakeInputs.python-dokuwiki;
                }
              );
              book-notes-sync = addDoc (
                pySelf.callPackage ./python-packages/book-notes-sync {
                  pkg-src = flakeInputs.book-notes-sync;
                }
              );
              daily_tactical_server = addDoc (
                pySelf.callPackage ./python-packages/daily_tactical_server {
                  inherit service-ports;
                  pkg-src = flakeInputs.daily_tactical_server;
                }
              );
              task-tools = addDoc (
                pySelf.callPackage ./python-packages/task-tools {
                  pkg-src = flakeInputs.task-tools;
                }
              );
              photos-tools = addDoc (
                pySelf.callPackage ./python-packages/photos-tools {
                  pkg-src = flakeInputs.photos-tools;
                }
              );
              wiki-tools = addDoc (
                pySelf.callPackage ./python-packages/wiki-tools {
                  pkg-src = flakeInputs.wiki-tools;
                }
              );
              mavlog-utils = addDoc (
                pySelf.callPackage ./python-packages/mavlog-utils {
                  pkg-src = flakeInputs.mavlog-utils;
                }
              );
              mesh-plotter = addDoc (
                pySelf.callPackage ./python-packages/mesh-plotter {
                  pkg-src = flakeInputs.mesh-plotter;
                }
              );
              makepyshell = addDoc (
                pySelf.callPackage ./python-packages/makepyshell {
                  pkg-src = flakeInputs.makepyshell;
                }
              );
              norbert = addDoc (pySelf.callPackage ./python-packages/norbert { });
              orchestrator = addDoc (
                pySelf.callPackage ./python-packages/orchestrator {
                  mp4 = final.mp4;
                  mp4unite = final.mp4;
                  scrape = final.scrape;
                  inherit service-ports;
                  pkg-src = flakeInputs.orchestrator;
                }
              );
              rcdo = addDoc (
                pySelf.callPackage ./python-packages/rcdo {
                  pkg-src = flakeInputs.rcdo;
                }
              );
              scrape = addDoc (
                pySelf.callPackage ./python-packages/scrape {
                  pkg-src = flakeInputs.scrape;
                }
              );
              spleeter = addDoc (pySelf.callPackage ./python-packages/spleeter { });
              trafficsim = addDoc (
                pySelf.callPackage ./python-packages/trafficsim {
                  pkg-src = flakeInputs.trafficsim;
                }
              );
              ichabod = addDoc (pySelf.callPackage ./python-packages/ichabod { });
              imutils-cv4 = addDoc (pySelf.callPackage ./python-packages/imutils-cv4 { });
              vidstab-cv4 = addDoc (pySelf.callPackage ./python-packages/vidstab-cv4 { });
              syrupy = addDoc (pySelf.callPackage ./python-packages/syrupy { });
              flask-hello-world = addDoc (pySelf.callPackage ./python-packages/flasks/hello-world { });
              flask-url2mp4 = addDoc (
                pySelf.callPackage ./python-packages/flasks/url2mp4 {
                  wget-pkg = prev.wget;
                }
              );
              flask-mp4server = addDoc (pySelf.callPackage ./python-packages/flasks/mp4server { });
              flask-mp3server = addDoc (pySelf.callPackage ./python-packages/flasks/mp3server { });
              flask-smfserver = addDoc (pySelf.callPackage ./python-packages/flasks/smfserver { });
              flask-oatbox = addDoc (pySelf.callPackage ./python-packages/flasks/oatbox { });
              rankserver = addDoc (pySelf.callPackage ./python-packages/flasks/rankserver { });
              stampserver = addDoc (pySelf.callPackage ./python-packages/flasks/stampserver { });
              authui = addDoc (pySelf.callPackage ./python-packages/flasks/authui { });
              budget_ui = addDoc (pySelf.callPackage ./python-packages/flasks/budget_ui { });
              pinned-mavproxy = addDoc (pySelf.callPackage ./python-packages/mavproxy { });
            }
          );
        }
      )
    );
in
rec {
  pkgsSource =
    {
      local ? false,
      rev ? null,
      ref ? null,
    }:
    let
      meta-info = if rev == null then ref else rev;
    in
    prev.stdenvNoCC.mkDerivation {
      name = "anixpkgs-src";
      src =
        if rev == null then
          (builtins.fetchTarball "https://github.com/goromal/anixpkgs/archive/${ref}.tar.gz")
        else
          (builtins.fetchGit {
            url = "https://github.com/goromal/anixpkgs";
            inherit rev;
            allRefs = true;
          });
      nativeBuildInputs = [ prev.git ];
      buildPhase = (
        if local then
          ''
            sed -i 's|local-build = false;|local-build = true;|g' "pkgs/nixos/dependencies.nix"
          ''
        else
          ""
      );
      installPhase = ''
        mkdir -p $out
        echo -n "${meta-info}" > ANIX_META
        cp -r * $out/
      '';
    };
  pkgData = prev.callPackage flakeInputs.anixdata { };

  writeArgparseScriptBin =
    pkgname: usagestr: opts: script:
    (
      let
        argparse = prev.callPackage ./bash-packages/bash-utils/argparse.nix {
          usage_str = usagestr;
          optsWithVarsAndDefaults = opts;
        };
      in
      prev.writeShellScriptBin pkgname ''
        ${argparse}
        ${script}
      ''
    );

  php74 = flakeInputs.phps.packages.${builtins.currentSystem}.php74;

  python310 = pythonOverridesFor prev.python310;
  python311 = pythonOverridesFor prev.python311;
  python313 = pythonOverridesFor prev.python313;

  aapis-py = final.python313.pkgs.aapis-py;
  budget_report = final.python313.pkgs.budget_report;
  surveys_report = final.python313.pkgs.surveys_report;
  makepyshell = final.python313.pkgs.makepyshell;
  mavlog-utils = final.python313.pkgs.mavlog-utils;
  fqt = final.python313.pkgs.fqt;
  ichabod = final.python313.pkgs.ichabod;
  norbert = final.python313.pkgs.norbert;
  geometry = final.python313.pkgs.geometry;
  pyceres = final.python313.pkgs.pyceres;
  pyceres_factors = final.python313.pkgs.pyceres_factors;
  pysorting = final.python313.pkgs.pysorting;
  pysignals = final.python313.pkgs.pysignals;
  mesh-plotter = final.python313.pkgs.mesh-plotter;
  scrape = final.python313.pkgs.scrape;
  # spleeter = final.python38.pkgs.spleeter;
  find_rotational_conventions = final.python313.pkgs.find_rotational_conventions;
  trafficsim = final.python313.pkgs.trafficsim;
  flask-hello-world = final.python313.pkgs.flask-hello-world;
  flask-url2mp4 = final.python313.pkgs.flask-url2mp4;
  flask-mp4server = final.python313.pkgs.flask-mp4server;
  flask-mp3server = final.python313.pkgs.flask-mp3server;
  flask-smfserver = final.python313.pkgs.flask-smfserver;
  flask-oatbox = final.python313.pkgs.flask-oatbox;
  daily_tactical_server = final.python313.pkgs.daily_tactical_server;
  imutils-cv4 = final.python313.pkgs.imutils-cv4;
  vidstab-cv4 = final.python313.pkgs.vidstab-cv4;
  symforce = final.python313.pkgs.symforce;
  rankserver = final.python313.pkgs.rankserver;
  rcdo = final.python313.pkgs.rcdo;
  stampserver = final.python313.pkgs.stampserver;
  authui = final.python313.pkgs.authui;
  budget_ui = final.python313.pkgs.budget_ui;
  easy-google-auth = final.python313.pkgs.easy-google-auth;
  task-tools = final.python313.pkgs.task-tools;
  photos-tools = final.python313.pkgs.photos-tools;
  python-dokuwiki = final.python313.pkgs.python-dokuwiki;
  wiki-tools = final.python313.pkgs.wiki-tools;
  book-notes-sync = final.python313.pkgs.book-notes-sync;
  gmail-parser = final.python313.pkgs.gmail-parser;
  goromail = final.python313.pkgs.goromail;
  orchestrator = final.python313.pkgs.orchestrator;

  authm = addDoc (prev.callPackage ./bash-packages/authm { python = python313; });
  manage-gmail = addDoc (
    prev.callPackage ./bash-packages/manage-gmail {
      python = final.python313;
    }
  );
  local-ssh-proxy = addDoc (prev.callPackage ./bash-packages/local-ssh-proxy { });
  gantter = addDoc (
    prev.callPackage ./bash-packages/gantter {
      python = final.python313;
      blank-svg = pkgData.img.blank-svg;
    }
  );
  la-quiz = addDoc (prev.callPackage ./bash-packages/la-quiz { python = final.python313; });
  play = addDoc (prev.callPackage ./bash-packages/play { });
  aapis-grpcurl = addDoc (prev.callPackage ./bash-packages/aapis-grpcurl { apis-fds = aapis-fds; });
  strings = addDoc (prev.callPackage ./bash-packages/bash-utils/strings.nix { });
  redirects = addDoc (prev.callPackage ./bash-packages/bash-utils/redirects.nix { });
  color-prints = addDoc (prev.callPackage ./bash-packages/color-prints { });
  ckfile = addDoc (prev.callPackage ./bash-packages/ckfile { });
  cpp-helper = addDoc (prev.callPackage ./bash-packages/cpp-helper { inherit anixpkgs-version; });
  py-helper = addDoc (prev.callPackage ./bash-packages/py-helper { inherit anixpkgs-version; });
  rust-helper = addDoc (
    prev.callPackage ./bash-packages/rust-helper {
      inherit anixpkgs-version;
    }
  );
  dirgroups = addDoc (prev.callPackage ./bash-packages/dirgroups { });
  dirgather = addDoc (prev.callPackage ./bash-packages/dirgather { });
  sread = addDoc (prev.callPackage ./bash-packages/srw/sread.nix { });
  swrite = addDoc (prev.callPackage ./bash-packages/srw/swrite.nix { });
  git-cc = addDoc (prev.callPackage ./bash-packages/git-cc { });
  git-shortcuts = addDoc (prev.callPackage ./bash-packages/git-shortcuts { });
  md2pdf = addDoc (prev.callPackage ./bash-packages/converters/md2pdf.nix { });
  mp4unite = addDoc (prev.callPackage ./bash-packages/mp4unite { });
  notabilify = addDoc (prev.callPackage ./bash-packages/converters/notabilify.nix { });
  make-title = addDoc (prev.callPackage ./bash-packages/make-title { });
  pb = addDoc (prev.callPackage ./bash-packages/pb { });
  code2pdf = addDoc (prev.callPackage ./bash-packages/converters/code2pdf.nix { });
  abc = addDoc (prev.callPackage ./bash-packages/converters/abc.nix { });
  doku = addDoc (prev.callPackage ./bash-packages/converters/doku.nix { });
  epub = addDoc (prev.callPackage ./bash-packages/converters/epub.nix { });
  gif = addDoc (prev.callPackage ./bash-packages/converters/gif.nix { });
  md = addDoc (prev.callPackage ./bash-packages/converters/md.nix { });
  mp3 = addDoc (prev.callPackage ./bash-packages/converters/mp3.nix { });
  mp4 = addDoc (prev.callPackage ./bash-packages/converters/mp4.nix { });
  pdf = addDoc (prev.callPackage ./bash-packages/converters/pdf.nix { });
  png = addDoc (prev.callPackage ./bash-packages/converters/png.nix { });
  svg = addDoc (
    prev.callPackage ./bash-packages/converters/svg.nix {
      scour = final.python313.pkgs.scour;
    }
  );
  zipper = addDoc (prev.callPackage ./bash-packages/converters/zipper.nix { });
  fix-perms = addDoc (prev.callPackage ./bash-packages/fix-perms { });
  setupws = addDoc (prev.callPackage ./bash-packages/setupws { });
  listsources = addDoc (prev.callPackage ./bash-packages/listsources { });
  pkgshell = addDoc (prev.callPackage ./bash-packages/pkgshell { });
  devshell = addDoc (prev.callPackage ./bash-packages/devshell { });
  providence = addDoc (prev.callPackage ./bash-packages/providence { });
  providence-tasker = addDoc (prev.callPackage ./bash-packages/providence/tasker.nix { });
  fixfname = addDoc (prev.callPackage ./bash-packages/fixfname { });
  nix-deps = addDoc (prev.callPackage ./bash-packages/nix-tools/nix-deps.nix { });
  nix-diffs = addDoc (prev.callPackage ./bash-packages/nix-tools/nix-diffs.nix { });
  anix-version = addDoc (prev.callPackage ./bash-packages/nix-tools/anix-version.nix { });
  anix-upgrade = addDoc (prev.callPackage ./bash-packages/nix-tools/anix-upgrade.nix { });
  anix-changelog-compare = addDoc (prev.callPackage ./bash-packages/anix-changelog-compare { });
  flake-update = addDoc (prev.callPackage ./bash-packages/nix-tools/flake-update.nix { });
  rcrsync = addDoc (prev.callPackage ./bash-packages/rcrsync { });
  getres = addDoc (prev.callPackage ./bash-packages/getres { });
  aptest = addDoc (
    prev.callPackage ./bash-packages/aptest {
      python = python313;
      mavproxy = python311.pkgs.pinned-mavproxy;
    }
  );

  aapis-cpp = addDoc (
    prev.callPackage ./cxx-packages/aapis-cpp {
      pkg-src = flakeInputs.aapis;
    }
  );
  ardurouter = (prev.callPackage ./cxx-packages/arducopter { }).router;
  arducopter = (prev.callPackage ./cxx-packages/arducopter { }).copter;
  manif-geom-cpp = addDoc (
    prev.callPackage ./cxx-packages/manif-geom-cpp {
      pkg-src = flakeInputs.manif-geom-cpp;
    }
  );
  quad-sim-cpp = addDoc (
    prev.callPackage ./cxx-packages/quad-sim-cpp {
      pkg-src = flakeInputs.quad-sim-cpp;
    }
  );
  mscpp = addDoc (prev.callPackage ./cxx-packages/mscpp { pkg-src = flakeInputs.mscpp; });
  orchestrator-cpp = addDoc (
    prev.callPackage ./cxx-packages/orchestrator-cpp {
      pkg-src = flakeInputs.orchestrator-cpp;
    }
  );
  ceres-factors = addDoc (
    prev.callPackage ./cxx-packages/ceres-factors {
      pkg-src = flakeInputs.ceres-factors;
    }
  );
  signals-cpp = addDoc (
    prev.callPackage ./cxx-packages/signals-cpp {
      pkg-src = flakeInputs.signals-cpp;
    }
  );
  gnc = addDoc (prev.callPackage ./cxx-packages/gnc { pkg-src = flakeInputs.gnc; });
  secure-delete = addDoc (
    prev.callPackage ./cxx-packages/secure-delete {
      pkg-src = flakeInputs.secure-delete;
    }
  );
  sorting = addDoc (
    prev.callPackage ./cxx-packages/sorting {
      pkg-src = flakeInputs.sorting;
    }
  );
  rankserver-cpp = addDoc (
    prev.callPackage ./cxx-packages/rankserver-cpp {
      pkg-src = flakeInputs.rankserver-cpp;
    }
  );
  crowcpp = addDoc (
    prev.callPackage ./cxx-packages/crowcpp {
      pkg-src = flakeInputs.crowcpp;
    }
  );
  mfn = addDoc (
    prev.callPackage ./cxx-packages/mfn {
      pkg-src = flakeInputs.mfn;
      model-proto = pkgData.models.gender.proto.data;
      model-weights = pkgData.models.gender.weights.data;
    }
  );

  evil-hangman = addDoc (
    prev.callPackage ./java-packages/evil-hangman (
      baseJavaArgs // { pkg-src = flakeInputs.evil-hangman; }
    )
  );
  spelling-corrector = addDoc (
    prev.callPackage ./java-packages/spelling-corrector (
      baseJavaArgs // { pkg-src = flakeInputs.spelling-corrector; }
    )
  );
  simple-image-editor = addDoc (
    prev.callPackage ./java-packages/simple-image-editor (
      baseJavaArgs // { pkg-src = flakeInputs.simple-image-editor; }
    )
  );

  manif-geom-rs = addDoc (
    prev.callPackage ./rust-packages/manif-geom-rs {
      pkg-src = flakeInputs.manif-geom-rs;
    }
  );
  xv-lidar-rs = addDoc (
    prev.callPackage ./rust-packages/xv-lidar-rs {
      pkg-src = flakeInputs.xv-lidar-rs;
    }
  );
  sunnyside = addDoc (
    prev.callPackage ./rust-packages/sunnyside {
      pkg-src = flakeInputs.sunnyside;
    }
  );

  nixos-machines = rec {
    personal = makeMachines "personal";
  };
  run-sitl-machine = prev.callPackage ./bash-packages/run-sitl {
    writeShellScriptBin = prev.writeShellScriptBin;
    callPackage = prev.callPackage;
    color-prints = prev.callPackage ./bash-packages/color-prints { };
    machines = [
      {
        name = "personal";
        description = "Personal Linux machine for the day-to-day.";
      }
    ];
  };

  multirotor-sim = prev.callPackage ./nixos/multirotor/run.nix baseModuleArgs;
}
