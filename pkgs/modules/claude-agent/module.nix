{ config, lib, ... }:
{
  options.machines.claude = {
    marketplaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of extra plugin marketplaces to install";
    };
    plugins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of claude plugins to install";
    };
    permissionsAllow = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of Claude Code permission patterns to add to the global allowlist";
    };
    hooks = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            event = lib.mkOption { type = lib.types.str; };
            matcher = lib.mkOption {
              type = lib.types.str;
              default = "";
            };
            command = lib.mkOption { type = lib.types.str; };
            async = lib.mkOption {
              type = lib.types.bool;
              default = false;
            };
          };
        }
      );
      default = [ ];
      description = "List of Claude Code hooks to merge into settings.json";
    };
    skills = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Skill directory name under ~/.claude/skills/";
            };
            file = lib.mkOption {
              type = lib.types.path;
              description = "Path to the SKILL.md file for this skill";
            };
          };
        }
      );
      default = [ ];
      description = "List of Claude Code skills to install into ~/.claude/skills/<name>/SKILL.md";
    };
    extraSettings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Attrs describing extra Claude JSON settings";
    };
    mcpServers = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [ ];
      description = "List of MCP server attrsets to register during claude-setup";
    };
  };

  config = lib.mkIf (lib.elem "claude" config.machines.base.agentFrameworks) {
    # Like `godev` (which drops you at the devshell workspace root), `goclaude`
    # takes you from anywhere inside a devshell to that workspace's `sources`
    # directory and opens claude there. `godev` is only defined inside a
    # devshell, so this is a no-op outside one.
    environment.shellAliases.goclaude = ''if [ -n "$DEVSHELL_ACTIVE" ]; then godev && cd sources && claude; else echo "goclaude: only available inside a devshell"; fi'';

    services.vikunja-mcp.enable = lib.mkDefault (
      builtins.any (s: s.name == "vikunja") config.machines.claude.mcpServers
    );
    services.notion-mcp.enable =
      config.machines.base.isATS || (config.machines.base.recreational && config.machines.base.developer);
    services.wiki-mcp.enable =
      config.machines.base.isATS || (config.machines.base.recreational && config.machines.base.developer);
  };
}
