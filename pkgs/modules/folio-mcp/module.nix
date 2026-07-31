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
    environment.systemPackages = [ pkgs.folio-mcp ];
  };
}
