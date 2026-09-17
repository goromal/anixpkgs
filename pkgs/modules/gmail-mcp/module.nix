{
  config,
  pkgs,
  lib,
  ...
}:
with import ../../nixos/dependencies.nix;
{
  options.services.gmail-mcp = {
    enable = lib.mkEnableOption "gmail MCP server for Claude Code and Codex";
  };

  config = lib.mkIf config.services.gmail-mcp.enable {
    environment.systemPackages = [ anixpkgs.gmail-mcp ];
  };
}
