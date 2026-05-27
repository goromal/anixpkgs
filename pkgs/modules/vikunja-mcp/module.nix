{
  config,
  pkgs,
  lib,
  ...
}:
let
  vikunja-mcp-server = pkgs.writeScriptBin "vikunja-mcp-server" ''
    #!${pkgs.python3}/bin/python3
    ${builtins.readFile ../vikunja/vikunja-mcp-server.py}
  '';
in
{
  options.services.vikunja-mcp = {
    enable = lib.mkEnableOption "Vikunja MCP server for Claude Code";
  };

  config = lib.mkIf config.services.vikunja-mcp.enable {
    environment.systemPackages = [ vikunja-mcp-server ];
  };
}
