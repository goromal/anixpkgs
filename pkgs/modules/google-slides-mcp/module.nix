{
  config,
  pkgs,
  lib,
  ...
}:
with import ../../nixos/dependencies.nix;
{
  options.services.google-slides-mcp = {
    enable = lib.mkEnableOption "Google Slides MCP server for Claude Code and Codex";
  };

  config = lib.mkIf config.services.google-slides-mcp.enable {
    environment.systemPackages = [ anixpkgs.google-slides-mcp ];
  };
}
