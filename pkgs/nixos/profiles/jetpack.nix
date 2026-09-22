{
  config,
  pkgs,
  lib,
  ...
}:
with import ../dependencies.nix;
let
  lock = builtins.fromJSON (builtins.readFile ../../../flake.lock);
  jetpackSrc = builtins.fetchTarball {
    url = "https://github.com/anduril/jetpack-nixos/archive/${lock.nodes.jetpack-nixos.locked.rev}.tar.gz";
    sha256 = lock.nodes.jetpack-nixos.locked.narHash;
  };
  jetpackModule = import (jetpackSrc + "/modules/default.nix") (import (jetpackSrc + "/overlay.nix"));
in
{
  imports = [
    jetpackModule
    ../pc-base.nix
  ];

  config = {
    # nixpkgs marks NCCL unsupported on pre-Thor Jetsons. PyTorch still carries
    # it as a dependency even though single-GPU services do not use it.
    nixpkgs.config.allowUnsupportedSystem = true;

    # All supported Orin variants use Ampere compute capability 8.7. Avoid
    # compiling large CUDA packages such as PyTorch for unrelated GPU targets.
    nixpkgs.config.cudaCapabilities = [ "8.7" ];
    nixpkgs.overlays = [ emulatedAarch64SdlTestsOverlay ];

    hardware.nvidia-jetpack.enable = true;
    hardware.nvidia-jetpack.configureCuda = true;
    hardware.graphics.enable = true;

    machines.base = {
      machineType = "jetson";
      cloudDirs = [
        {
          name = "configs";
          cloudname = "dropbox:configs";
          dirname = "configs";
        }
        {
          name = "secrets";
          cloudname = "dropbox:secrets";
          dirname = "secrets";
        }
        {
          name = "data";
          cloudname = "box:data";
          dirname = "data";
        }
      ];
    };
    machines.features = {
      desktop.enable = false;
      development.enable = true;
      recreation.enable = false;
      headsetAudio.enable = false;
      externalDrives.enable = true;
      homeVpn.enable = false;
      agentUi.enable = true;
      upgradeUi.enable = true;
      fileServers.enable = true;
      metrics.enable = true;
      notesWiki.enable = false;
      orchestrator.enable = true;
      auth.enable = false;
      budget.enable = false;
      languageQuiz.enable = false;
      music.enable = false;
      tester.enable = false;
      disciple.enable = false;
      tasks.enable = false;
      videoDownload.enable = false;
      brom.enable = true;
      intake.enable = false;
      mail.enable = false;
      plex.enable = false;
      vikunja.enable = false;
      gameStreaming.enable = false;
      gpu.enable = true;
      notebooks.enable = true;
      imageGeneration.enable = true;
      localLlm.enable = false;
      folio.enable = false;
      tactical.enable = false;
      agents.frameworks = [
        "claude"
        "codex"
      ];
      orchestrator.extraPackages = [
        anixpkgs.wiki-tools
        anixpkgs.task-tools
        anixpkgs.notion-tools
        anixpkgs.goromail
        anixpkgs.sread
        anixpkgs.gmail-parser
        anixpkgs.providence-tasker
        anixpkgs.daily_tactical_server
        anixpkgs.surveys_report
      ];
    };
    users.users.andrew.hashedPassword = lib.mkForce "$6$Kof8OUytwcMojJXx$vc82QBfFMxCJ96NuEYsrIJ0gJORjgpkeeyO9PzCBgSGqbQePK73sa13oK1FGY1CGd09qbAlsdiXWmO6m9c3K.0";
    environment.systemPackages = [
      anixpkgs.jetson-stats
    ];
  };
}
