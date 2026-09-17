# Evaluate externally visible profile behavior without building the system.
{
  configuration ? null,
  evaluated ? null,
}:
let
  system = if evaluated != null then evaluated else import <nixpkgs/nixos> { inherit configuration; };
  inherit (system) config pkgs;
  inherit (pkgs) lib;
  services = [
    "agent_ui"
    "anix-upgrade-ui"
    "authui"
    "brom"
    "budget_ui"
    "comfyui"
    "disciple"
    "folio-backend"
    "homeVpnNode"
    "intake_ui"
    "la-quiz-web"
    "launchpad"
    "mailNode"
    "mail_ui"
    "metricsNode"
    "navidrome-ats"
    "nginx"
    "notes-wiki"
    "ollama"
    "orchestrator_ui"
    "orchestratord"
    "plexNode"
    "rankserver"
    "stampserver"
    "sunset"
    "sunshine"
    "tacticald"
    "tasks_ui"
    "tester"
    "vdlserver"
    "vikunja-ats"
  ];
in
{
  failedAssertions = map (a: a.message) (lib.filter (a: !a.assertion) config.assertions);
  features = lib.mapAttrs (name: _: config.machines.features.${name}.enable) (
    import ../pkgs/nixos/features/catalog.nix
  );
  frameworks = config.machines.features.agents.frameworks;
  enabledServices = lib.filter (name: config.services.${name}.enable) services;
  units = builtins.attrNames (lib.filterAttrs (_: unit: unit.enable) config.systemd.services);
  timers = builtins.attrNames config.systemd.timers;
  tcpPorts = config.networking.firewall.allowedTCPPorts;
  routes = lib.mapAttrs (
    _: host: builtins.attrNames host.locations
  ) config.services.nginx.virtualHosts;
  webServices = map (s: { inherit (s) name path port; }) config.machines.base.webServices;
  jobs = map (job: job.name) config.machines.features.orchestrator.jobs;
  # Force scripts as well as names so derivation/path coercion is checked.
  jobScripts = map (job: {
    inherit (job) jobShellScript execStartPre;
  }) config.machines.features.orchestrator.jobs;
  jobPanels = map (panel: panel.title) (
    lib.filter (panel: panel.group == "Job Logs") config.services.metricsNode.panels
  );
  tmpfiles = config.systemd.tmpfiles.rules;
  cuda = config.machines.cudaNode.enable;
  folioHub = config.services.folio-backend.isHub;
  folioDesktop = config.services.folio-backend.desktop;
  claudePlugins = config.machines.claude.plugins;
}
