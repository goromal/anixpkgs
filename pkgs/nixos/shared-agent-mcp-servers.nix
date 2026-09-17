{ homeDir }:
let
  ports = import ./service-ports.nix;
in
{
  vikunja = {
    name = "vikunja";
    command = "/run/current-system/sw/bin/vikunja-mcp-server";
    env = {
      VIKUNJA_URL = "https://ats.local:${toString ports.vikunja.public}";
      VIKUNJA_INSECURE = "1";
    };
    secretsEnv.VIKUNJA_TOKEN_FILE = "${homeDir}/secrets/vikunja/secrets.json";
  };
  folio = {
    name = "folio";
    command = "/run/current-system/sw/bin/folio-mcp-server";
    env.FOLIO_API_URL = "http://localhost:${toString ports.folio.internal}";
  };
  notion = {
    name = "notion";
    command = "/run/current-system/sw/bin/notion-mcp-server";
    secretsEnv.NOTION_TOKEN_FILE = "${homeDir}/secrets/notion/secret.json";
  };
  wiki = {
    name = "wiki";
    command = "/run/current-system/sw/bin/wiki-mcp-server";
    env.WIKI_URL = "http://ats.local";
    secretsEnv.WIKI_SECRETS_DIR = "${homeDir}/secrets/wiki";
  };
  jupyter = {
    name = "jupyter-mcp";
    command = "/run/current-system/sw/bin/jupyter-mcp-server";
    env.SERVER_URL = "http://localhost:${toString ports.launchpad}";
  };
  googleSheets = {
    name = "google-sheets";
    command = "/run/current-system/sw/bin/mcp-google-sheets-locked";
    secretsEnv = {
      CREDENTIALS_PATH = "${homeDir}/secrets/google/client_secrets.json";
      TOKEN_PATH = "${homeDir}/secrets/google/refresh.json";
    };
  };
  gmail = {
    name = "gmail";
    command = "/run/current-system/sw/bin/gmail-mcp-server";
    env.GMAIL_ADDRESS = "andrew.torgesen@gmail.com";
    secretsEnv = {
      GMAIL_SECRETS_JSON = "${homeDir}/secrets/google/client_secrets.json";
      GMAIL_REFRESH_FILE = "${homeDir}/secrets/google/refresh.json";
    };
  };
}
