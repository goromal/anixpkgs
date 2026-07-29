{
  pkgs,
  config,
  lib,
  ...
}:
with import ../dependencies.nix;
let
  cfg = config.mods.upgradeHooks;

  # Realize a single hook as a oneshot user service whose ExecStart script
  # embeds every watched store path. The script's own store hash therefore
  # changes iff a watched path or the command changed, so home-manager only
  # restarts (re-runs) the unit during a switch when the relevant code changed.
  hookService = hook: {
    name = "upgrade-hook-${hook.name}";
    value = {
      Unit = {
        Description = "Post-upgrade on-change hook: ${hook.name}";
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "upgrade-hook-${hook.name}" ''
          set -e
          # color-prints/coreutils for hook ergonomics, plus the user profile so
          # hooks can invoke user-installed tools (claude, rtk, gh, ...).
          export PATH="${
            lib.makeBinPath [
              anixpkgs.color-prints
              pkgs.coreutils
            ]
          }:$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:$PATH"
          # Watched paths (embedded so this script's store hash tracks their content):
          ${lib.concatMapStringsSep "\n" (p: ": # watch ${p}") hook.watch}
          echo_yellow "Running post-upgrade hook: ${hook.name}"
          ${hook.command}
        '';
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
in
{
  options.mods.upgradeHooks = lib.mkOption {
    type = lib.types.listOf (
      lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Identifier for this hook (used as the systemd unit name suffix)";
          };
          watch = lib.mkOption {
            type = lib.types.listOf lib.types.path;
            description = "Store paths whose content, if changed, should trigger the hook";
          };
          command = lib.mkOption {
            type = lib.types.str;
            description = "Shell command to run when a watched path changes on upgrade";
          };
          description = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Human-readable description of what the hook does";
          };
        };
      }
    );
    default = [ ];
    description = ''
      List of post-upgrade on-change hooks. Each hook becomes a oneshot user
      service that re-runs during `nixos-rebuild switch` (as performed by
      anix-upgrade) only when one of its watched store paths changed. Leaf
      modules append their own hooks so change-detection stays self-contained.
    '';
  };

  config = {
    systemd.user.services = builtins.listToAttrs (map hookService cfg);
  };
}
