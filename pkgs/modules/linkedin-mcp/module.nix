{
  config,
  pkgs,
  lib,
  ...
}:
let
  linkedin-mcp-server = pkgs.writeShellScriptBin "linkedin-mcp-server" ''
    exec ${pkgs.uv}/bin/uvx linkedin-mcp-server "$@"
  '';
in
{
  options.services.linkedin-mcp = {
    enable = lib.mkEnableOption "LinkedIn MCP server for Claude Code";
  };

  config = lib.mkIf config.services.linkedin-mcp.enable {
    environment.systemPackages = [ linkedin-mcp-server ];
  };
}
