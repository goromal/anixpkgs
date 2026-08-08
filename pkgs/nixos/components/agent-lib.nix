{ pkgs, lib }:
rec {
  # Shared MCP-server submodule. Codex extends usage with args/startup_timeout_sec;
  # Claude ignores those. `command` is an absolute path to the server executable.
  mcpServerType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "MCP server name (table key / `claude mcp add` name)";
      };
      command = lib.mkOption {
        type = lib.types.str;
        description = "Absolute path to the MCP server executable";
      };
      args = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Arguments passed to the server (codex config.toml only)";
      };
      env = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Plain (non-secret) environment variables for the server";
      };
      startupTimeoutSec = lib.mkOption {
        type = lib.types.nullOr lib.types.number;
        default = null;
        description = "codex startup_timeout_sec (codex config.toml only)";
      };
      secretsPath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path checked for existence; if missing, registration is skipped";
      };
      secretsEnvVar = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Env var that should receive secretsPath";
      };
    };
  };

  # Build a systemd user oneshot that deep-merges Nix-managed `settings` (an attrset)
  # into `targetFile`, preserving user edits. `format` selects JSON (jq) vs TOML
  # (dasel<->jq round-trip). The create-if-absent / atomic-write scaffolding is shared.
  #
  #   name        : service key + Description suffix
  #   targetFile  : shell string, e.g. "$HOME/.codex/config.toml"
  #   format      : "json" | "toml"
  #   settings    : attrset rendered to JSON and merged with `existing * nixos`
  #   extraMerge  : list of { name; varName; valueJson; jqProgram; } — each applied as an
  #                 extra `jq --argjson <varName> <valueJson> '<jqProgram>'` pass AFTER the base deep-merge
  mkAgentSettingsService =
    {
      name,
      description,
      targetFile,
      format,
      settings,
      extraMerge ? [ ],
    }:
    let
      settingsJson = builtins.toJSON settings;
      jq = "${pkgs.jq}/bin/jq";
      dasel = "${pkgs.dasel}/bin/dasel";
      coreutils = pkgs.coreutils;

      readToJson =
        if format == "toml" then
          ''${dasel} -f "$TARGET" -r toml -w json''
        else
          ''${coreutils}/bin/cat "$TARGET"'';
      writeFromJson =
        if format == "toml" then
          ''${dasel} -f "$TMP" -r json -w toml > "$TARGET"''
        else
          ''${coreutils}/bin/cp "$TMP" "$TARGET"'';
      initFromJson =
        if format == "toml" then
          ''echo '${settingsJson}' | ${dasel} -r json -w toml > "$TARGET"''
        else
          ''echo '${settingsJson}' > "$TARGET"'';

      extraMergeSteps = lib.concatMapStringsSep "\n" (m: ''
        ${jq} --argjson ${m.varName} '${m.valueJson}' '${m.jqProgram}' "$TARGET" > "$TMP" && ${coreutils}/bin/mv "$TMP" "$TARGET"
        echo "Applied ${m.name} merge"
      '') extraMerge;

      mergeScript = pkgs.writeShellScript "merge-${name}-settings" ''
        set -e
        TARGET="${targetFile}"
        TMP="$TARGET.tmp"
        NIXOS='${settingsJson}'
        ${coreutils}/bin/mkdir -p "$(${coreutils}/bin/dirname "$TARGET")"

        if [ ! -f "$TARGET" ]; then
          ${initFromJson}
          echo "Created ${name} settings from NixOS configuration"
        else
          ${jq} -n \
            --argjson existing "$(${readToJson})" \
            --argjson nixos "$NIXOS" \
            '$existing * $nixos' > "$TMP"
          ${writeFromJson}
          ${coreutils}/bin/rm -f "$TMP"
          echo "Updated ${name} settings, preserving user modifications"
        fi

        ${extraMergeSteps}
      '';
    in
    {
      Unit.Description = description;
      Service = {
        Type = "oneshot";
        ExecStart = "${mergeScript}";
        RemainAfterExit = true;
      };
      Install.WantedBy = [ "default.target" ];
    };
}
