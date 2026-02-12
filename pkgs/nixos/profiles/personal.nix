{
  config,
  pkgs,
  lib,
  ...
}:
with import ../dependencies.nix { system = pkgs.stdenv.hostPlatform.system; };
{
  imports = [ ../pc-base.nix ];

  config =
    (mkProfileConfig {
      machineType = "x86_linux";
      graphical = true;
      recreational = true;
      developer = true;
      isATS = false;
      serveNotesWiki = false;
      enableMetrics = true;
      enableFileServers = false;
      cloudDirs = [
        {
          name = "configs";
          cloudname = "dropbox:configs";
          dirname = "configs";
        }
        {
          name = "secrets";
          cloudname = "dropbox:secrets";
          dirname = "secrets";
        }
        {
          name = "data";
          cloudname = "box:data";
          dirname = "data";
        }
        {
          name = "documents";
          cloudname = "drive:Documents";
          dirname = "Documents";
        }
        {
          name = "games";
          cloudname = "dropbox:games";
          dirname = "games";
        }
        {
          name = "games2";
          cloudname = "drive:MoreGames";
          dirname = "more-games";
        }
      ];
      enableOrchestrator = true;
      timedOrchJobs = [
        {
          name = "budgets-backup";
          jobShellScript = pkgs.writeShellScript "budgets-backup" ''
            rcrsync override data budgets || { logger -t budgets-backup "Budgets backup UNSUCCESSFUL"; >&2 echo "backup error!"; exit 1; }
            logger -t budgets-backup "Budgets backup successful 🎆"
          '';
          timerCfg = {
            OnBootSec = "5m";
            OnUnitActiveSec = "60m";
          };
        }
      ];
      extraOrchestratorPackages = [ ];
    })
    // {
      environment.systemPackages = [
        (pkgs.writeShellScriptBin "anix-init" ''
          make-title -c yellow "Setting up rcrsync"

          DO_RCLONE=y
          if [[ -f $HOME/.config/rclone/rclone.conf ]]; then
            read -rp "rclone config already found, proceed anyway? (y|n): " DO_RCLONE
          fi
          if [[ "$DO_RCLONE" == "y" ]]; then
            read -rp "Enter the char key to unlock the rclone config: " CFGKEY
            rm -rf $HOME/.config/rclone
            mkdir -p $HOME/.config/rclone && cd $HOME/.config/rclone
            cp ${anixpkgs.pkgData.records.rcloneConf.data} ${anixpkgs.pkgData.records.rcloneConf.name}
            sunnyside -s 0 -k $CFGKEY -t ${anixpkgs.pkgData.records.rcloneConf.name}
            rm ${anixpkgs.pkgData.records.rcloneConf.name}
          else
            echo_yellow "Skipping rclone config step"
          fi

          cd $HOME
          rcrsync -v init configs
          rcrsync -v init secrets
          rcrsync -v init data
          rcrsync -v init documents
          rcrsync -v init games
          rcrsync -v init games2

          make-title -c yellow "Setting up SSH and Nix"

          DO_SSH=y
          if [[ -d $HOME/.ssh ]]; then
            read -rp ".ssh directory already present, proceed anyway? (y|n): " DO_SSH
          fi
          if [[ "$DO_SSH" == "y" ]]; then
            rm -rf $HOME/.ssh
            cp -r $HOME/data/.ssh $HOME/.ssh
            cd $HOME/.ssh
            fix-perms .
            cd ..
          else
            echo_yellow "Skipping SSH config setup"
          fi

          sudo nix-channel --add https://nixos.org/channels/nixos-${nixos-version} nixpkgs
          sudo nix-channel --add https://nixos.org/channels/nixos-${nixos-version} nixos
          sudo nix-channel --add https://github.com/nix-community/home-manager/archive/release-${nixos-version}.tar.gz home-manager
          sudo nix-channel --update
          echo
          echo
          echo_green "DONE. Note the hardware-config.nix file below:"
          echo
          nixos-generate-config --show-hardware-config
          echo
          echo_green  "Use the config above as you set up anix-upgrade:"
          echo_yellow "  - Use devshell to create a workspace with anixpkgs"
          echo_yellow "  - Use the config above to define a new configuration in anixpkgs"
          echo_yellow "  - Symlink /etc/nixos/configuration.nix to $HOME/sources"
          echo_yellow "  - Run anix-upgrade"
          echo_yellow "  - Create new secrets and configs entries"
          echo
          echo_green "Have fun!"
        '')
      ];
    };
}
