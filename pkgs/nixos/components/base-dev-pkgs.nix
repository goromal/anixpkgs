{
  pkgs,
  config,
  lib,
  ...
}:
with import ../dependencies.nix;
let
  cfg = config.mods.opts;

  mcpServerSetupScript =
    server:
    let
      envFlags = lib.concatStringsSep " " (
        lib.mapAttrsToList (k: v: "-e ${k}=${lib.escapeShellArg v}") server.env
      );
      secretsFlag =
        if server.secretsEnvVar != null then
          "-e ${server.secretsEnvVar}=${lib.escapeShellArg server.secretsPath}"
        else
          "";
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
in
{
  home.packages = [
    pkgs.direnv
    anixpkgs.aapis-grpcurl
    anixpkgs.flake-update
    anixpkgs.git-cc
    anixpkgs.git-shortcuts
    anixpkgs.setupws
    anixpkgs.listsources
    anixpkgs.pkgshell
    (anixpkgs.devshell.override { editorName = cfg.editor; })
    (pkgs.writeShellScriptBin "dsd" ''
      devshell $@ --run dev
    '')
    anixpkgs.cpp-helper
    anixpkgs.py-helper
    anixpkgs.rust-helper
    anixpkgs.makepyshell
    pkgs.gh
    pkgs.universal-ctags
    anixpkgs.claude-code-bin
    anixpkgs.rtk
    # First-time bring-up on a new machine: registers marketplaces, installs plugins,
    # configures MCP servers (Vikunja/Notion/Wiki), runs `rtk init`, and prompts for `gh auth login`.
    (pkgs.writeShellScriptBin "claude-setup" ''
      if ! command -v claude &> /dev/null; then
        echo_red "Error: claude not found in PATH"
        exit 1
      fi
      echo_yellow "Installing claude plugins..."
      ${lib.concatMapStringsSep "\n      " (
        marketplace: "claude plugin marketplace add ${marketplace}"
      ) cfg.claudeMarketplaces}
      ${lib.concatMapStringsSep "\n      " (plugin: "claude plugin install ${plugin}") cfg.claudePlugins}
      echo_green "Done! Verify installed plugins with \"claude plugin list\""

      ${lib.concatMapStringsSep "\n" mcpServerSetupScript cfg.claudeMcpServers}

      echo_yellow "Installing rtk Claude Code hook..."
      rtk init -g
      echo_green "rtk hook installed"

      echo_yellow "Other setup..."
      read -p "Proceed with gh CLI setup? (y|n) " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        gh auth login
      fi
    '')
    # Run periodically to pull the latest plugin code from configured marketplaces.
    # Refreshes marketplace metadata, then updates each configured plugin. Restart claude after.
    (pkgs.writeShellScriptBin "claude-update" ''
      if ! command -v claude &> /dev/null; then
        echo_red "Error: claude not found in PATH"
        exit 1
      fi
      echo_yellow "Updating claude marketplaces..."
      claude plugin marketplace update
      echo_yellow "Updating claude plugins..."
      ${lib.concatMapStringsSep "\n      " (
        plugin: "claude plugin update ${plugin} || true"
      ) cfg.claudePlugins}
      echo_green "Done! Restart claude for updates to take effect."
    '')
  ];

  home.file = builtins.listToAttrs (
    map (skill: {
      name = ".claude/skills/${skill.name}/SKILL.md";
      value = {
        source = skill.file;
      };
    }) cfg.claudeSkills
  );

  programs.git = {
    package = pkgs.gitFull;
    enable = true;
    settings = {
      user = {
        name = "Andrew Torgesen";
        email = "andrew.torgesen@gmail.com";
      };
      alias = {
        aa = "add -A";
        cm = "commit -m";
        co = "checkout";
        cp = "cherry-pick";
        s = "status";
        d = "diff";
      };
      init = {
        defaultBranch = "master";
      };
      push = {
        default = "current";
      };
      pull = {
        default = "current";
      };
    };
  };

  services.lorri.enable = true;

  programs.vim.plugins = lib.mkIf (cfg.standalone == false) (
    with pkgs.vimPlugins;
    [
      vim-gitgutter
      YouCompleteMe
    ]
  );

  systemd.user.services.claude-settings-update =
    let
      pluginsObj = builtins.listToAttrs (
        map (plugin: {
          name = plugin;
          value = true;
        }) cfg.claudePlugins
      );
      baseConfig = {
        enabledPlugins = pluginsObj;
      };
      nixosSettings = baseConfig // cfg.extraClaudeSettings;
      nixosSettingsJson = builtins.toJSON nixosSettings;

      # Group hooks by event and convert to Claude Code settings format
      hooksByEvent = lib.groupBy (h: h.event) cfg.claudeHooks;
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
      permissionsAllowJson = builtins.toJSON cfg.claudePermissionsAllow;

      mergeScript = pkgs.writeShellScript "merge-claude-settings" ''
        set -e

        SETTINGS_DIR="$HOME/.claude"
        SETTINGS_FILE="$SETTINGS_DIR/settings.json"
        NIXOS_SETTINGS='${nixosSettingsJson}'
        NIXOS_HOOKS='${hooksJson}'
        NIXOS_PERMISSIONS_ALLOW='${permissionsAllowJson}'

        # Create directory if it doesn't exist
        ${pkgs.coreutils}/bin/mkdir -p "$SETTINGS_DIR"

        # If settings file doesn't exist, just write the NixOS settings
        if [ ! -f "$SETTINGS_FILE" ]; then
          echo "$NIXOS_SETTINGS" > "$SETTINGS_FILE"
          echo "Created new Claude settings file with NixOS configuration"
        else
          # Merge existing settings with NixOS settings
          # NixOS settings take precedence for conflicts
          ${pkgs.jq}/bin/jq -n \
            --argjson existing "$(${pkgs.coreutils}/bin/cat "$SETTINGS_FILE")" \
            --argjson nixos "$NIXOS_SETTINGS" \
            '$existing * $nixos' > "$SETTINGS_FILE.tmp"

          ${pkgs.coreutils}/bin/mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
          echo "Updated Claude settings, preserving user modifications"
        fi

        # Append declarative hooks, deduplicating by command
        if [ "$NIXOS_HOOKS" != "{}" ]; then
          ${pkgs.jq}/bin/jq \
            --argjson new_hooks "$NIXOS_HOOKS" \
            'reduce ($new_hooks | to_entries[]) as $ev (
              .;
              .hooks[$ev.key] = (
                (.hooks[$ev.key] // []) + $ev.value
                | unique_by(.hooks[0].command)
              )
            )' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
          ${pkgs.coreutils}/bin/mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
          echo "Merged declarative hooks into Claude settings"
        fi

        # Append declarative permissions allowlist, deduplicating
        if [ "$NIXOS_PERMISSIONS_ALLOW" != "[]" ]; then
          ${pkgs.jq}/bin/jq \
            --argjson new_allow "$NIXOS_PERMISSIONS_ALLOW" \
            '.permissions.allow = ((.permissions.allow // []) + $new_allow | unique)' \
            "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
          ${pkgs.coreutils}/bin/mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
          echo "Merged declarative permissions into Claude settings"
        fi
      '';
    in
    {
      Unit = {
        Description = "Update Claude Code settings with NixOS configuration";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${mergeScript}";
        RemainAfterExit = true;
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
}
