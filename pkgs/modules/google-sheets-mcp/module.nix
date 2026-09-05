{
  config,
  lib,
  pkgs,
  ...
}:
let
  requirements = pkgs.writeText "mcp-google-sheets-requirements.txt" (
    builtins.readFile ./requirements.txt
  );
  googleSheetsMcp = pkgs.writeShellScriptBin "mcp-google-sheets-locked" ''
    exec ${pkgs.uv}/bin/uvx \
      --from "mcp-google-sheets==0.6.3" \
      --with-requirements ${requirements} \
      mcp-google-sheets "$@"
  '';
in
{
  options.services.google-sheets-mcp = {
    enable = lib.mkEnableOption "Google Sheets MCP server launcher";
  };

  config = lib.mkIf config.services.google-sheets-mcp.enable {
    # The server runs from a complete reviewed dependency lock, rather than
    # resolving mutable PyPI versions every time an MCP client starts it.
    environment.systemPackages = [ googleSheetsMcp ];
  };
}
