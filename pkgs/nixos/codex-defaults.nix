# Default Codex configuration values, referenced by profiles.
#
# Unlike claude-defaults.nix (whose MCP secret paths use "$HOME/..." and are
# shell-expanded by claude-setup at `claude mcp add` time), codex reads
# ~/.codex/config.toml literally — TOML values are NOT shell-expanded. So MCP
# secret paths must be absolute, which is why this is a function of the machine's
# homeDir. Codex also has no secrets-existence guard (claude-setup skips a server
# whose secret file is missing); a codex MCP server whose secret is absent simply
# errors when first invoked.
{ homeDir }:
let
  ports = import ./service-ports.nix;
in
{
  model = "gpt-5.6";
  modelProvider = "openai";
  approvalPolicy = "never";
  sandboxMode = "danger-full-access";
  extraSettings = {
    model_reasoning_effort = "medium";
  };

  mcpServers = {
    vikunja = {
      name = "vikunja";
      command = "/run/current-system/sw/bin/vikunja-mcp-server";
      env = {
        VIKUNJA_URL = "https://ats.local:${toString ports.vikunja.public}";
        VIKUNJA_INSECURE = "1";
        VIKUNJA_TOKEN_FILE = "${homeDir}/secrets/vikunja/secrets.json";
      };
    };
    notion = {
      name = "notion";
      command = "/run/current-system/sw/bin/notion-mcp-server";
      env = {
        NOTION_TOKEN_FILE = "${homeDir}/secrets/notion/secret.json";
      };
    };
    wiki = {
      name = "wiki";
      command = "/run/current-system/sw/bin/wiki-mcp-server";
      env = {
        WIKI_SECRETS_DIR = "${homeDir}/secrets/wiki";
      };
    };
    jupyter = {
      name = "jupyter-mcp";
      command = "/run/current-system/sw/bin/jupyter-mcp-server";
      env = {
        SERVER_URL = "http://localhost:${toString ports.launchpad}";
      };
    };
    googleSheets = {
      name = "google-sheets";
      command = "/run/current-system/sw/bin/mcp-google-sheets-locked";
      env = {
        CREDENTIALS_PATH = "${homeDir}/secrets/google/client_secrets.json";
        TOKEN_PATH = "${homeDir}/secrets/google/refresh.json";
      };
    };
  };
}
