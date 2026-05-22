{
  pkgs,
  config,
  lib,
  ...
}:
with import ../dependencies.nix;
{
  options.mods.opts = {
    standalone = lib.mkOption {
      type = lib.types.bool;
      description = "Whether this is a standalone Nix installation (default: false)";
      default = false;
    };
    homeDir = lib.mkOption {
      type = lib.types.str;
      description = "Home directory to put the wallpaper in (default: /data/andrew)";
      default = "/data/andrew";
    };
    homeState = lib.mkOption {
      type = lib.types.str;
      description = "Initiating state of home-manager (example: '22.05')";
    };
    userOrchestrator = lib.mkOption {
      type = lib.types.bool;
      description = "Whether to run a user-domain instance of orchestratord (default: true)";
      default = true;
    };
    cloudDirs = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      description = "List of {name,cloudname,dirname} attributes (dirname is relative to home) defining the syncable directories by rcrsync";
    };
    editor = lib.mkOption {
      type = lib.types.str;
      description = "Code editor (executable) of choice";
      default = "code";
    };
    browserExec = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      description = "Executable name to open your browser of choice";
      default = null;
    };
    wallpaperImage = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      description = "Path to desired wallpaper (for graphical distributions)";
      default = null;
    };
    screenResolution = lib.mkOption {
      type = lib.types.str;
      description = "Screen resolution in [width]x[height] format";
      default = "1920x1080";
    };
    enableMetrics = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to export OS metrics";
    };
    claudeMarketplaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of extra plugin marketplaces to install";
    };
    claudePlugins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of claude plugins to install";
    };
    claudePermissionsAllow = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of Claude Code permission patterns to add to the global allowlist";
    };
    claudeSkills = lib.mkOption {
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
    claudeHooks = lib.mkOption {
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
    extraClaudeSettings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Attrs describing the Claude JSON settings";
    };
    claudeMcpServers = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "MCP server name (passed to `claude mcp add`)";
            };
            command = lib.mkOption {
              type = lib.types.str;
              description = "Absolute path to the MCP server executable";
            };
            env = lib.mkOption {
              type = lib.types.attrsOf lib.types.str;
              default = { };
              description = "Plain (non-secret) environment variables for the server";
            };
            secretsPath = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Path checked for existence; if missing, server registration is skipped";
            };
            secretsEnvVar = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Name of env var that should receive secretsPath (the server reads + parses it)";
            };
          };
        }
      );
      default = [ ];
      description = "List of MCP servers to register with claude during claude-setup";
    };
  };
}
