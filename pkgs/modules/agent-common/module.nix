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
  flakeInputs = config.nixpkgs.config.flakeInputs or { };
  sharedSkillCatalog =
    if builtins.hasAttr "agent-skills" flakeInputs then
      import "${flakeInputs.agent-skills}/catalog.nix"
    else
      [ ];
  localSkillCatalog = import ../../nixos/shared-agent-skills.nix;
  skillCatalog = builtins.filter (
    skill: !(lib.elem skill.name config.machines.agents.excludedSkills)
  ) (sharedSkillCatalog ++ localSkillCatalog);
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
  hasCloudDir = name: builtins.any (dir: dir.name == name) config.machines.base.cloudDirs;
in
{
  options.machines.agents.excludedSkills = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Shared agent skills to omit on this machine";
  };
  options.machines.agents.privateSkills = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = ''
      Skill directory names linked (out of the Nix store, live-editable) from
      privateSkillsDir into every enabled agent framework's skill roots. For
      skills whose content must not live in any repository.
    '';
  };
  options.machines.agents.privateSkillsDir = lib.mkOption {
    type = lib.types.str;
    default = "${config.machines.base.homeDir}/configs/private-skills";
    description = "Directory holding one <name>/SKILL.md folder per private skill";
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
        assertions = [
          (
            let
              clash = lib.intersectLists config.machines.agents.privateSkills (
                map (skill: skill.name) skillCatalog
              );
            in
            {
              assertion = clash == [ ];
              message = "machines.agents.privateSkills collides with public skills: ${lib.concatStringsSep ", " clash}";
            }
          )
        ];
      }
      {
        machines.agents.privateSkills = lib.mkIf (lib.all hasCloudDir [
          "configs"
          "secrets"
        ]) [ "atsudo" ];
      }
      {
        services.vikunja-mcp.enable = hasServer "vikunja";
        services.folio-mcp.enable = hasServer "folio";
        services.notion-mcp.enable = hasServer "notion";
        services.wiki-mcp.enable = hasServer "wiki";
        services.jupyter-mcp.enable = hasServer "jupyter-mcp";
        services.google-sheets-mcp.enable = hasServer "google-sheets";
        services.google-slides-mcp.enable = hasServer "google-slides";
        services.gmail-mcp.enable = hasServer "gmail";
        # A failed settings merge leaves agents on stale config (e.g. missing
        # MCP servers) without any visible error.
        services.bitd.checks = map (framework: "${framework}_settings") frameworks;
      }
    ]
  );
}
