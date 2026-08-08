{ pkgs, config, lib, ... }:
with import ../dependencies.nix;
let
  cfg = config.mods.codex;
  agentLib = import ./agent-lib.nix { inherit pkgs lib; };
  codexPkg = flakeInputs.llm-agents.packages.${pkgs.system}.codex;

  mcpServersAttr = builtins.listToAttrs (map (s: {
    name = s.name;
    value = {
      command = s.command;
      args = s.args;
      env = s.env;
    } // lib.optionalAttrs (s.startupTimeoutSec != null) {
      startup_timeout_sec = s.startupTimeoutSec;
    };
  }) cfg.mcpServers);

  codexSettings = {
    model = cfg.model;
    model_provider = cfg.modelProvider;
    approval_policy = cfg.approvalPolicy;
    sandbox_mode = cfg.sandboxMode;
    mcp_servers = mcpServersAttr;
  } // cfg.extraSettings;

  codexSetup = pkgs.writeShellScriptBin "codex-setup" ''
    if ! command -v codex &> /dev/null; then
      echo "Error: codex not found in PATH" >&2
      exit 1
    fi
    echo "codex config is managed declaratively via ~/.codex/config.toml"
    if [ -t 0 ]; then
      read -p "Run 'codex login' now? (y|n) " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        codex login || true
      fi
    else
      echo "Non-interactive session; skipping codex login."
    fi
  '';

  codexUpdate = pkgs.writeShellScriptBin "codex-update" ''
    echo "codex is pinned via nix (llm-agents.nix). Version: $(codex --version 2>/dev/null || echo unknown)"
  '';
in
{
  imports = [ ./upgrade-hooks.nix ];

  options.mods.codex = {
    model = lib.mkOption { type = lib.types.str; default = "gpt-5.6"; };
    modelProvider = lib.mkOption { type = lib.types.str; default = "openai"; };
    approvalPolicy = lib.mkOption { type = lib.types.str; default = "on-request"; };
    sandboxMode = lib.mkOption { type = lib.types.str; default = "workspace-write"; };
    extraSettings = lib.mkOption { type = lib.types.attrs; default = { }; };
    mcpServers = lib.mkOption { type = lib.types.listOf agentLib.mcpServerType; default = [ ]; };
    graphical = lib.mkOption { type = lib.types.bool; default = false; };
  };

  config = {
    home.packages = [ codexPkg codexSetup codexUpdate ];

    # NOTE: the Codex VSCode extension (openai.chatgpt) is intentionally deferred.
    # It is a platform-specific bundle shipping native ELF binaries that require
    # autoPatchelf; tabled for a later pass. The `graphical` option is retained
    # for when it lands. See docs/superpowers/plans notes.

    systemd.user.services.codex-settings-update = agentLib.mkAgentSettingsService {
      name = "codex";
      description = "Update Codex config.toml with NixOS configuration";
      targetFile = "$HOME/.codex/config.toml";
      format = "toml";
      settings = codexSettings;
    };

    mods.upgradeHooks = [
      {
        name = "codex-setup";
        watch = [ codexSetup ];
        command = "${codexSetup}/bin/codex-setup";
        description = "Re-run codex-setup when its script content changes";
      }
    ];
  };
}
