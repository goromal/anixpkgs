{
  pkgs,
  config,
  lib,
  ...
}:
with import ../dependencies.nix;
let
  cfg = config.mods.opts;
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
    unstable.claude-code
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

      ${lib.optionalString cfg.vikunjaEnabled ''
        echo_yellow "Setting up Vikunja MCP server..."
        SECRETS_FILE="$HOME/secrets/vikunja/secrets.json"
        if [ -f "$SECRETS_FILE" ]; then
          VIKUNJA_TOKEN=$(${pkgs.jq}/bin/jq -r '.token // empty' "$SECRETS_FILE" 2>/dev/null || echo "")

          if [ -n "$VIKUNJA_TOKEN" ]; then
            # Remove existing vikunja server if present
            claude mcp remove vikunja 2>/dev/null || true

            # Add the Vikunja MCP server
            claude mcp add -s user \
              -e VIKUNJA_URL=https://ats.local:3457 \
              -e VIKUNJA_API_TOKEN="$VIKUNJA_TOKEN" \
              -e VIKUNJA_INSECURE=1 \
              -- vikunja /run/current-system/sw/bin/vikunja-mcp-server

            echo_green "Vikunja MCP server registered successfully"
          else
            echo_yellow "Warning: 'token' not found in $SECRETS_FILE. Skipping Vikunja MCP setup."
          fi
        else
          echo_yellow "Warning: Secrets file $SECRETS_FILE not found. Skipping Vikunja MCP setup."
        fi
      ''}

      ${lib.optionalString cfg.notionMcpEnabled ''
        echo_yellow "Setting up Notion MCP server..."
        NOTION_SECRETS="$HOME/secrets/notion/secret.json"
        if [ -f "$NOTION_SECRETS" ]; then
          claude mcp remove notion 2>/dev/null || true
          claude mcp add -s user \
            -e NOTION_TOKEN_FILE="$NOTION_SECRETS" \
            -- notion /run/current-system/sw/bin/notion-mcp-server
          echo_green "Notion MCP server registered successfully"
        else
          echo_yellow "Warning: $NOTION_SECRETS not found. Skipping Notion MCP setup."
        fi
      ''}

      echo_yellow "Other setup..."
      read -p "Proceed with gh CLI setup? (y|n) " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        gh auth login
      fi
    '')
  ];

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

      mergeScript = pkgs.writeShellScript "merge-claude-settings" ''
        set -e

        SETTINGS_DIR="$HOME/.claude"
        SETTINGS_FILE="$SETTINGS_DIR/settings.json"
        NIXOS_SETTINGS='${nixosSettingsJson}'

        # Create directory if it doesn't exist
        mkdir -p "$SETTINGS_DIR"

        # If settings file doesn't exist, just write the NixOS settings
        if [ ! -f "$SETTINGS_FILE" ]; then
          echo "$NIXOS_SETTINGS" > "$SETTINGS_FILE"
          echo "Created new Claude settings file with NixOS configuration"
          exit 0
        fi

        # Merge existing settings with NixOS settings
        # NixOS settings take precedence for conflicts
        ${pkgs.jq}/bin/jq -n \
          --argjson existing "$(cat "$SETTINGS_FILE")" \
          --argjson nixos "$NIXOS_SETTINGS" \
          '$existing * $nixos' > "$SETTINGS_FILE.tmp"

        mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
        echo "Updated Claude settings, preserving user modifications"
      '';
    in
    {
      Unit = {
        Description = "Update Claude Code settings with NixOS configuration";
        After = [ "graphical-session-pre.target" ];
        PartOf = [ "graphical-session.target" ];
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
