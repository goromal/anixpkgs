{
  config,
  lib,
  ...
}:
with import ../../nixos/dependencies.nix;
{
  options.services.jupyter-mcp = {
    enable = lib.mkEnableOption "Jupyter MCP server for Claude Code";
    serverUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://localhost:${toString service-ports.launchpad}";
      description = "URL of the Jupyter server";
    };
  };

  config = lib.mkIf config.services.jupyter-mcp.enable {
    environment.systemPackages = [ anixpkgs.jupyter-mcp-server ];
  };
}
