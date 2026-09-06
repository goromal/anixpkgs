{ config, lib, ... }:
let
  frameworks = config.machines.base.agentFrameworks;
  enabled = frameworks != [ ];
  defaults = import ../../nixos/shared-agent-mcp-servers.nix {
    homeDir = config.machines.base.homeDir;
  };
  mcpServers = builtins.attrValues defaults;
  skills = builtins.filter (skill: !(lib.elem skill.name config.machines.agents.excludedSkills)) (
    import ../../nixos/shared-agent-skills.nix
  );
  hasServer = name: builtins.any (server: server.name == name) mcpServers;
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
        machines.claude = {
          inherit skills mcpServers;
        };
      })
      (lib.mkIf (lib.elem "codex" frameworks) {
        machines.codex = {
          inherit skills mcpServers;
        };
      })
      {
        services.vikunja-mcp.enable = hasServer "vikunja";
        services.folio-mcp.enable = hasServer "folio";
        services.notion-mcp.enable = hasServer "notion";
        services.wiki-mcp.enable = hasServer "wiki";
        services.jupyter-mcp.enable = hasServer "jupyter-mcp";
        services.google-sheets-mcp.enable = hasServer "google-sheets";
      }
    ]
  );
}
