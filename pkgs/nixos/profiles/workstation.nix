{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [ ../pc-base.nix ];

  config = {
    machines.base = {
      machineType = "x86_linux";
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
          name = "documents";
          cloudname = "drive:Documents";
          dirname = "Documents";
        }
      ];
    };
    machines.features = {
      desktop.enable = true;
      development.enable = true;
      recreation.enable = false;
      headsetAudio.enable = false;
      externalDrives.enable = true;
      homeVpn.enable = false;
      agentUi.enable = false;
      upgradeUi.enable = false;
      fileServers.enable = false;
      metrics.enable = false;
      notesWiki.enable = false;
      orchestrator.enable = false;
      auth.enable = false;
      budget.enable = false;
      languageQuiz.enable = false;
      music.enable = false;
      tester.enable = false;
      disciple.enable = false;
      tasks.enable = false;
      videoDownload.enable = false;
      brom.enable = false;
      intake.enable = false;
      mail.enable = false;
      plex.enable = false;
      vikunja.enable = false;
      gameStreaming.enable = false;
      gpu.enable = false;
      notebooks.enable = false;
      imageGeneration.enable = false;
      localLlm.enable = false;
      folio.enable = false;
      tactical.enable = false;
      agents.frameworks = [ "claude" ];
      orchestrator.jobs = [ ];
      orchestrator.extraPackages = [ ];
    };
    machines.agents.excludedSkills = [ "workspace-development" ];
  };
}
