{ config, lib, ... }:
let
  claudeDefaults = import ../../nixos/claude-defaults.nix;
  codexDefaults = import ../../nixos/codex-defaults.nix;
  frameworks = config.machines.features.agents.frameworks;
  enabled = frameworks != [ ];
  mcpServerCatalog = builtins.attrValues (
    import ../../nixos/shared-agent-mcp-servers.nix {
      homeDir = config.machines.base.homeDir;
    }
  );
  skillCatalog = builtins.filter (
    skill: !(lib.elem skill.name config.machines.agents.excludedSkills)
  ) (import ../../nixos/shared-agent-skills.nix);
  forFramework =
    framework: catalog:
    map (entry: builtins.removeAttrs entry [ "frameworks" ]) (
      builtins.filter (
        entry:
        lib.elem framework (
          entry.frameworks or [
            "claude"
            "codex"
          ]
        )
      ) catalog
    );
  mcpServersFor = framework: forFramework framework mcpServerCatalog;
  skillsFor = framework: forFramework framework skillCatalog;
  activeMcpServers = lib.concatMap mcpServersFor frameworks;
  hasServer = name: builtins.any (server: server.name == name) activeMcpServers;
in
{
  options.machines.agents.excludedSkills = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Shared agent skills to omit on this machine";
  };

  config = lib.mkIf enabled (
    lib.mkMerge [
      (lib.mkIf (lib.elem "claude" frameworks) {
        machines.claude = (lib.mapAttrs (_: lib.mkDefault) claudeDefaults) // {
          skills = skillsFor "claude";
          mcpServers = mcpServersFor "claude";
        };
      })
      (lib.mkIf (lib.elem "codex" frameworks) {
        machines.codex = (lib.mapAttrs (_: lib.mkDefault) codexDefaults) // {
          skills = skillsFor "codex";
          mcpServers = mcpServersFor "codex";
        };
      })
      {
        services.vikunja-mcp.enable = hasServer "vikunja";
        services.folio-mcp.enable = hasServer "folio";
        services.notion-mcp.enable = hasServer "notion";
        services.wiki-mcp.enable = hasServer "wiki";
        services.jupyter-mcp.enable = hasServer "jupyter-mcp";
        services.google-sheets-mcp.enable = hasServer "google-sheets";
        services.gmail-mcp.enable = hasServer "gmail";
      }
    ]
  );
}
