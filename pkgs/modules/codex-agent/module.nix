{
  config,
  lib,
  pkgs,
  ...
}:
let
  agentLib = import ../../nixos/components/agent-lib.nix { inherit pkgs lib; };
in
{
  options.machines.codex = {
    model = lib.mkOption {
      type = lib.types.str;
      default = "gpt-5.6";
      description = "Default codex model";
    };
    modelProvider = lib.mkOption {
      type = lib.types.str;
      default = "openai";
      description = "codex model_provider";
    };
    approvalPolicy = lib.mkOption {
      type = lib.types.enum [
        "on-request"
        "untrusted"
        "never"
        "granular"
      ];
      default = "on-request";
      description = "codex approval_policy";
    };
    sandboxMode = lib.mkOption {
      type = lib.types.enum [
        "read-only"
        "workspace-write"
        "danger-full-access"
      ];
      default = "danger-full-access";
      description = "codex sandbox_mode";
    };
    extraSettings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Extra keys merged into ~/.codex/config.toml";
    };
    skills = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Skill directory name under ~/.agents/skills/";
            };
            file = lib.mkOption {
              type = lib.types.path;
              description = "Path to the SKILL.md file for this skill";
            };
          };
        }
      );
      default = [ ];
      description = "List of Codex skills to install into ~/.agents/skills/<name>/SKILL.md";
    };
    mcpServers = lib.mkOption {
      type = lib.types.listOf agentLib.mcpServerType;
      default = [ ];
      description = "MCP servers written into ~/.codex/config.toml [mcp_servers]";
    };
  };

  config = lib.mkIf (lib.elem "codex" config.machines.base.agentFrameworks) {
    # gocodex: from anywhere in a devshell, jump to sources/ and open codex
    # (mirrors the claude module's goclaude alias).
    environment.shellAliases.gocodex = ''if [ -n "$DEVSHELL_ACTIVE" ]; then godev && cd sources && codex; else echo "gocodex: only available inside a devshell"; fi'';
  };
}
