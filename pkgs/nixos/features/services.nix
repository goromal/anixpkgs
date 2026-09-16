{
  config,
  pkgs,
  lib,
  ...
}:
with import ../dependencies.nix;
let
  cfg = config.machines.base;
  features = config.machines.features;
  inherit (import ../runtime.nix { inherit config pkgs lib; }) machine-rcrsync machine-authm;
in
{
  config = {
    services.authui = {
      enable = features.auth.enable;
      initScript =
        (pkgs.writeShellScriptBin "atsauthui-start" ''
          ${lib.optionalString features.orchestrator.enable "${pkgs.systemd}/bin/systemctl stop orchestratord"}
        '')
        + "/bin/atsauthui-start";
      resetScript =
        (pkgs.writeShellScriptBin "atsauthui-finish" ''
          ${machine-rcrsync}/bin/rcrsync override secrets
          ${lib.optionalString features.orchestrator.enable "${pkgs.systemd}/bin/systemctl start orchestratord"}
        '')
        + "/bin/atsauthui-finish";
    };

    services.budget_ui = {
      enable = features.budget.enable;
      pathPkgs = [
        pkgs.bash
        pkgs.coreutils
        pkgs.util-linux
        pkgs.rclone
        machine-rcrsync
        machine-authm
        anixpkgs.budget_report
        anixpkgs.fixfname
      ];
    };

    services.orchestrator_ui = {
      enable = features.orchestrator.enable;
    };

    services.anix-upgrade-ui = {
      enable = features.upgradeUi.enable;
    };

    services.agent_ui.enable = features.agentUi.enable;

    services.rankserver = {
      enable = features.fileServers.enable;
      package = anixpkgs.rankserver;
      rootDir = "${cfg.homeDir}/fileservers";
    };

    services.stampserver = {
      enable = features.fileServers.enable;
      package = anixpkgs.stampserver;
      rootDir = "${cfg.homeDir}/fileservers";
    };

    services.la-quiz-web = {
      enable = features.languageQuiz.enable;
      dataDir = "${cfg.homeDir}/data/la-quiz-web";
    };

    services.navidrome-ats = {
      enable = features.music.enable;
      dataDir = "${cfg.homeDir}/data/navidrome";
    };

    services.tester = {
      enable = features.tester.enable;
      dataDir = "${cfg.homeDir}/data/tester";
    };

    services.disciple = {
      enable = features.disciple.enable;
    };

    services.tasks_ui = {
      enable = features.tasks.enable;
      rcrsync = machine-rcrsync;
    };

    services.vdlserver = {
      enable = features.videoDownload.enable;
    };

    services.brom = {
      enable = features.brom.enable;
    };

    services.intake_ui = {
      enable = features.intake.enable;
    };

    services.mail_ui = {
      enable = features.mail.enable;
      rcrsync = machine-rcrsync;
    };

    # Metrics
    services.metricsNode.enable = features.metrics.enable;
    services.metricsNode.openFirewall = features.metrics.enable;

    # External drives
    machines.externalDrives.enable = features.externalDrives.enable;

    # Notes Wiki
    services.notes-wiki.enable = features.notesWiki.enable;

    # Daily Tactical
    services.tacticald = lib.mkIf features.tactical.enable {
      enable = true;
      user = "andrew";
      group = "dev";
      tacticalPkg = anixpkgs.daily_tactical_server;
      statsdPort = lib.mkIf features.metrics.enable service-ports.statsd;
    };

    # Media
    services.plexNode.enable = features.plex.enable;

    # Mail
    services.mailNode.enable = features.mail.enable;

    # Vikunja Task Management
    services.vikunja-ats = lib.mkIf features.vikunja.enable {
      enable = true;
      domain = "${config.networking.hostName}.local";
    };

    machines.cudaNode.enable = features.gpu.enable;
    services.launchpad.enable = features.notebooks.enable;
    services.comfyui.enable = features.imageGeneration.enable;
    machines.localLlm.enable = features.localLlm.enable;
    services.homeVpnNode.enable = features.homeVpn.enable;
    services.folio-backend = {
      enable = features.folio.enable;
      isHub = features.folio.role == "hub";
      desktop = features.folio.desktop;
      hubHost = if features.folio.role == "hub" then "" else features.folio.hubHost;
    };
    users.users.andrew.extraGroups = lib.mkIf features.vikunja.enable [ "vikunja" ];
  };
}
