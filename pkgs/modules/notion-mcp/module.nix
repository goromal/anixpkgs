{
  config,
  pkgs,
  lib,
  ...
}:
let
  notion-mcp-server = pkgs.writeScriptBin "notion-mcp-server" ''
    #!${pkgs.python3}/bin/python3
    ${builtins.readFile ./notion-mcp-server.py}
  '';
in
{
  options.services.notion-mcp = {
    enable = lib.mkEnableOption "Notion MCP server for Claude Code";
  };

  config = lib.mkIf config.services.notion-mcp.enable {
    environment.systemPackages = [ notion-mcp-server ];
  };
}
