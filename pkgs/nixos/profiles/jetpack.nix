{
  config,
  pkgs,
  lib,
  ...
}:
with import ../dependencies.nix;
{
  imports = [ ../pc-base.nix ];

  config =
    (mkProfileConfig {
      machineType = "jetson";
      graphical = false;
      recreational = false;
      developer = true;
      isATS = false;
      serveNotesWiki = false;
      enableMetrics = false; # TODO: perhaps enable in the future
      enableFileServers = true;
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
      ];
      enableOrchestrator = true;
      timedOrchJobs = [ ];
      extraOrchestratorPackages = [
        anixpkgs.wiki-tools
        anixpkgs.task-tools
        anixpkgs.notion-tools
        anixpkgs.goromail
        anixpkgs.sread
        anixpkgs.gmail-parser
        anixpkgs.providence-tasker
        anixpkgs.daily_tactical_server
        anixpkgs.surveys_report
      ];
    })
    // {
      users.users.andrew.hashedPassword = lib.mkForce "$6$Kof8OUytwcMojJXx$vc82QBfFMxCJ96NuEYsrIJ0gJORjgpkeeyO9PzCBgSGqbQePK73sa13oK1FGY1CGd09qbAlsdiXWmO6m9c3K.0";
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

          echo
          echo_green "DONE. Note the hardware-config.nix file below:"
          echo
          nixos-generate-config --show-hardware-config
          echo
          echo_green  "Next steps to finish configuring this machine:"
          echo_yellow "  - Use devshell to create a workspace with anixpkgs"
          echo_yellow "  - Copy the hardware config above to anixpkgs/pkgs/nixos/hardware/<hostname>.nix"
          echo_yellow "  - Create a new configuration in anixpkgs/pkgs/nixos/configurations/"
          echo_yellow "  - Add the configuration to nixosConfigurations in anixpkgs/flake.nix (key must match hostname)"
          echo_yellow "  - Run anix-upgrade"
          echo_yellow "  - Create new secrets and configs entries"
          echo
          echo_green "Have fun!"
        '')
      ];
    };
}
