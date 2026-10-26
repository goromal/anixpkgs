{
  config,
  pkgs,
  lib,
  ...
}:
with import ../../nixos/dependencies.nix;
let
  wiki-mcp-script = pkgs.writeScript "wiki-mcp-server" ''
    #!${pkgs.python3}/bin/python3
    ${builtins.readFile ./wiki-mcp-server.py}
  '';
  # The server shells out to sread, which itself calls coreutils and grep by
  # bare name. Agent sandboxes run with a minimal PATH, so pin them here.
  wiki-mcp-server = pkgs.runCommand "wiki-mcp-server" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
    makeWrapper ${wiki-mcp-script} $out/bin/wiki-mcp-server \
      --prefix PATH : ${
        lib.makeBinPath [
          anixpkgs.sread
          pkgs.coreutils
          pkgs.gnugrep
        ]
      }
  '';
in
{
  options.services.wiki-mcp = {
    enable = lib.mkEnableOption "Wiki MCP server for local coding agents";
  };

  config = lib.mkIf config.services.wiki-mcp.enable {
    environment.systemPackages = [ wiki-mcp-server ];
  };
}
