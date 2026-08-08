{
  pkgs,
  config,
  lib,
  ...
}:
with import ../dependencies.nix;
let
  cfg = config.mods.claude;

  agentLib = import ./agent-lib.nix { inherit pkgs lib; };

  claudeCodeVersion = "2.1.116";
  claudeCodeExt =
    let
      base = builtins.head (
        pkgs.vscode-utils.extensionsFromVscodeMarketplace [
          {
            name = "claude-code";
            publisher = "anthropic";
            version = claudeCodeVersion;
            sha256 = "sha256-myBC6iy7EsA1at4QKWjgiq3TRuC4VMqeH4jop9zo4BM=";
          }
        ]
      );
    in
    pkgs.stdenvNoCC.mkDerivation {
      name = "vscode-extension-anthropic-claude-code-${claudeCodeVersion}-nixos";
      version = claudeCodeVersion;
      dontUnpack = true;
      dontBuild = true;
      installPhase = ''
        cp -r ${base} $out
        chmod -R u+w $out
        mkdir -p $out/share/vscode/extensions/anthropic.claude-code/resources/native-binaries/linux-x64
        ln -s ${anixpkgs.claude-code-bin}/bin/claude \
          $out/share/vscode/extensions/anthropic.claude-code/resources/native-binaries/linux-x64/claude
      '';
      passthru = {
        vscodeExtUniqueId = base.vscodeExtUniqueId;
        vscodeExtPublisher = base.vscodeExtPublisher;
        vscodeExtName = base.vscodeExtName;
      };
    };

  mcpServerSetupScript =
    server:
    let
      envFlags = lib.concatStringsSep " " (
        lib.mapAttrsToList (k: v: "-e ${k}=${lib.escapeShellArg v}") server.env
      );
      secretsFlag =
        if server.secretsEnvVar != null then "-e ${server.secretsEnvVar}=${server.secretsPath}" else "";
      hasSecretsCheck = server.secretsPath != null;
      registerCmd = ''
        claude mcp remove ${server.name} 2>/dev/null || true
        claude mcp add -s user ${envFlags} ${secretsFlag} \
          -- ${server.name} ${server.command}
        echo_green "${server.name} MCP server registered successfully"
      '';
    in
    ''
      echo_yellow "Setting up ${server.name} MCP server..."
    ''
    + (
      if hasSecretsCheck then
        ''
          if [ -e "${server.secretsPath}" ]; then
            ${registerCmd}
          else
            echo_yellow "Warning: ${server.secretsPath} not found. Skipping ${server.name} MCP setup."
          fi
        ''
      else
        registerCmd
    );

  # Status line script (see res/claude-statusline.sh). PATH is prepended so the
  # jq/date/coreutils it relies on resolve regardless of the caller's env.
  statuslineScript = pkgs.writeShellScript "claude-statusline" ''
    export PATH="${
      lib.makeBinPath [
        pkgs.jq
        pkgs.coreutils
      ]
    }:$PATH"
    ${builtins.readFile ../res/claude-statusline.sh}
  '';

  # claude-setup as a named derivation so its store path can be watched by an
  # upgrade hook (re-run setup only when this script's content changes). The gh
  # auth step is TTY-guarded so the hook can run it non-interactively.
  claudeSetupScript = pkgs.writeShellScriptBin "claude-setup" ''
    if ! command -v claude &> /dev/null; then
      echo_red "Error: claude not found in PATH"
      exit 1
    fi
    echo_yellow "Installing claude plugins..."
    ${lib.concatMapStringsSep "\n      " (
      marketplace: "claude plugin marketplace add ${marketplace}"
    ) cfg.marketplaces}
    ${lib.concatMapStringsSep "\n      " (plugin: "claude plugin install ${plugin}") cfg.plugins}
    echo_green "Done! Verify installed plugins with \"claude plugin list\""

    ${lib.concatMapStringsSep "\n" mcpServerSetupScript cfg.mcpServers}

    echo_yellow "Installing rtk Claude Code hook..."
    rtk init -g
    echo_green "rtk hook installed"

    echo_yellow "Other setup..."
    if [ -t 0 ]; then
      read -p "Proceed with gh CLI setup? (y|n) " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        gh auth login
      fi
    else
      echo_yellow "Non-interactive session; skipping gh auth login."
    fi
  '';
in
{
  # Pull in the generic upgrade-hooks option so this leaf module can define its
  # own on-change hooks regardless of how it is imported (NixOS pc-base or a
  # standalone home.nix). Module imports dedupe by path, so pc-base importing
  # upgrade-hooks.nix too is harmless.
  imports = [ ./upgrade-hooks.nix ];

  options.mods.claude = {
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
      type = lib.types.listOf agentLib.mcpServerType;
      default = [ ];
      description = "List of MCP servers to register with claude during claude-setup";
    };
    graphical = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether the machine has a graphical environment (enables VSCode extension)";
    };
  };

  config = {
    home.packages = [
      anixpkgs.claude-code-bin
      anixpkgs.rtk
      claudeSetupScript
      (pkgs.writeShellScriptBin "claude-update" ''
        if ! command -v claude &> /dev/null; then
          echo_red "Error: claude not found in PATH"
          exit 1
        fi
        echo_yellow "Updating claude marketplaces..."
        claude plugin marketplace update
        echo_yellow "Updating claude plugins..."
        ${lib.concatMapStringsSep "\n      " (plugin: "claude plugin update ${plugin} || true") cfg.plugins}
        echo_green "Done! Restart claude for updates to take effect."
      '')
    ];

    home.file = builtins.listToAttrs (
      map (skill: {
        name = ".claude/skills/${skill.name}/SKILL.md";
        value = {
          source = skill.file;
        };
      }) cfg.skills
    );

    programs.vscode.profiles.default.extensions = lib.mkIf cfg.graphical [ claudeCodeExt ];

    programs.vscode.profiles.default.userSettings = lib.mkIf cfg.graphical {
      "claudeCode.preferredLocation" = "panel";
    };

    systemd.user.services.claude-settings-update =
      let
        pluginsObj = builtins.listToAttrs (
          map (plugin: {
            name = plugin;
            value = true;
          }) cfg.plugins
        );
        baseConfig = {
          enabledPlugins = pluginsObj;
          statusLine = {
            type = "command";
            command = "${statuslineScript}";
            padding = 0;
          };
        };
        nixosSettings = baseConfig // cfg.extraSettings;

        hooksByEvent = lib.groupBy (h: h.event) cfg.hooks;
        hooksConfig = lib.mapAttrs (
          _event: entries:
          map (h: {
            matcher = h.matcher;
            hooks = [
              (
                {
                  type = "command";
                  command = h.command;
                }
                // lib.optionalAttrs h.async { async = true; }
              )
            ];
          }) entries
        ) hooksByEvent;
        hooksJson = builtins.toJSON hooksConfig;
        permissionsAllowJson = builtins.toJSON cfg.permissionsAllow;
      in
      agentLib.mkAgentSettingsService {
        name = "claude";
        description = "Update Claude Code settings with NixOS configuration";
        targetFile = "$HOME/.claude/settings.json";
        format = "json";
        settings = nixosSettings;
        extraMerge =
          (lib.optional (hooksConfig != { }) {
            name = "hooks";
            varName = "new_hooks";
            valueJson = hooksJson;
            jqProgram = "reduce ($new_hooks | to_entries[]) as $ev (.; .hooks[$ev.key] = ((.hooks[$ev.key] // []) + $ev.value | unique_by(.hooks[0].command)))";
          })
          ++ (lib.optional (cfg.permissionsAllow != [ ]) {
            name = "permissions";
            varName = "new_allow";
            valueJson = permissionsAllowJson;
            jqProgram = ".permissions.allow = ((.permissions.allow // []) + $new_allow | unique)";
          });
      };

    # Re-run claude-setup after an upgrade only when the setup script's content
    # changes (new plugins/marketplaces/MCP servers). Settings-file regen is
    # already handled by the claude-settings-update unit above, which is itself
    # an on-change oneshot (the reference pattern this hook generalizes).
    mods.upgradeHooks = [
      {
        name = "claude-setup";
        watch = [ claudeSetupScript ];
        command = "${claudeSetupScript}/bin/claude-setup";
        description = "Re-run claude-setup when its script content changes";
      }
    ];
  };
}
