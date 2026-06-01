{
  config,
  pkgs,
  lib,
  ...
}:
let
  wiki-mcp-server = pkgs.writeScriptBin "wiki-mcp-server" ''
    #!${pkgs.python3}/bin/python3
    ${builtins.readFile ./wiki-mcp-server.py}
  '';
in
{
  options.services.wiki-mcp = {
    enable = lib.mkEnableOption "Wiki MCP server for Claude Code";
  };

  config = lib.mkIf config.services.wiki-mcp.enable {
    environment.systemPackages = [ wiki-mcp-server ];
  };
}
