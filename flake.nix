{
  description =
    "A collection of personal (or otherwise personally useful) software packaged in Nix.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=refs/tags/23.05";

    flake-compat.url = "github:edolstra/flake-compat";
    flake-compat.flake = false;

    flake-utils.url = "github:numtide/flake-utils";

    anixdata.url = "github:goromal/anixdata";
    anixdata.flake = false;

    aapis.url = "github:goromal/aapis";
    aapis.flake = false;

    ceres-factors.url = "github:goromal/ceres-factors";
    ceres-factors.flake = false;

    crowcpp.url = "github:goromal/Crow";
    crowcpp.flake = false;

    manif-geom-cpp.url = "github:goromal/manif-geom-cpp";
    manif-geom-cpp.flake = false;

    mfn.url = "github:goromal/mfn";
    mfn.flake = false;

    mscpp.url = "github:goromal/mscpp";
    mscpp.flake = false;

    quad-sim-cpp.url = "github:goromal/quad-sim-cpp";
    quad-sim-cpp.flake = false;

    rankserver-cpp.url = "github:goromal/rankserver-cpp";
    rankserver-cpp.flake = false;

    secure-delete.url = "github:goromal/secure-delete";
    secure-delete.flake = false;

    signals-cpp.url = "github:goromal/signals-cpp";
    signals-cpp.flake = false;

    sorting.url = "github:goromal/sorting";
    sorting.flake = false;

    evil-hangman.url = "github:goromal/evil-hangman";
    evil-hangman.flake = false;

    simple-image-editor.url = "github:goromal/simple-image-editor";
    simple-image-editor.flake = false;

    spelling-corrector.url = "github:goromal/spelling-corrector";
    spelling-corrector.flake = false;

    book-notes-sync.url = "github:goromal/book-notes-sync";
    book-notes-sync.flake = false;

    easy-google-auth.url = "github:goromal/easy-google-auth";
    easy-google-auth.flake = false;

    find_rotational_conventions.url =
      "git+https://gist.github.com/fb15f44150ca4e0951acaee443f72d3e";
    find_rotational_conventions.flake = false;

    geometry.url = "github:goromal/geometry";
    geometry.flake = false;

    gmail-parser.url = "github:goromal/gmail_parser";
    gmail-parser.flake = false;

    makepyshell.url =
      "git+https://gist.github.com/e64b6bdc8a176c38092e9bde4c434d31";
    makepyshell.flake = false;

    mavlog-utils.url = "github:goromal/mavlog-utils";
    mavlog-utils.flake = false;

    mesh-plotter.url = "github:goromal/mesh-plotter";
    mesh-plotter.flake = false;

    orchestrator.url = "github:goromal/orchestrator";
    orchestrator.flake = false;

    pyceres.url =
      "github:Edwinem/ceres_python_bindings?rev=2106d043bce37adcfef450dd23d3005480948c37";
    pyceres.flake = false;

    pyceres_factors.url = "github:goromal/pyceres_factors";
    pyceres_factors.flake = false;

    pysignals.url = "github:goromal/pysignals";
    pysignals.flake = false;

    pysorting.url = "github:goromal/pysorting";
    pysorting.flake = false;

    python-dokuwiki.url = "github:fmenabe/python-dokuwiki?ref=refs/tags/1.3.3";
    python-dokuwiki.flake = false;

    scrape.url = "github:goromal/scrape";
    scrape.flake = false;

    task-tools.url = "github:goromal/task-tools";
    task-tools.flake = false;

    trafficsim.url =
      "git+https://gist.github.com/c37629235750b65b9d0ec0e17456ee96";
    trafficsim.flake = false;

    wiki-tools.url = "github:goromal/wiki-tools";
    wiki-tools.flake = false;

    manif-geom-rs.url = "github:goromal/manif-geom-rs?ref=dev/impl";
    manif-geom-rs.flake = false;

    xv-lidar-rs.url = "github:goromal/xv-lidar-rs";
    xv-lidar-rs.flake = false;
  };

  outputs = { self, nixpkgs, flake-utils, ... }@inputs:
    let supported-systems = [ "x86_64-linux" "aarch64-linux" ];
    in flake-utils.lib.eachSystem supported-systems (system: {
      legacyPackages = import nixpkgs {
        inherit system;
        overlays = [ (import ./overlay.nix) ];
        config = {
          allowUnfree = true;
          flakeInputs = inputs;
        };
      };
    });
}
