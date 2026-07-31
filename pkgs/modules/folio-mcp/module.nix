{
  config,
  pkgs,
  lib,
  ...
}:
{
  options.services.folio-mcp = {
    enable = lib.mkEnableOption "folio MCP server for Claude Code";
  };

  config = lib.mkIf config.services.folio-mcp.enable {
    # folio-mcp exposes the `folio-mcp-server` console script.
    environment.systemPackages = [ pkgs.folio-mcp ];
  };
}
