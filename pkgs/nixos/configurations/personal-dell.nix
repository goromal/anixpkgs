{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ../profiles/personal.nix
    ../hardware/dell.nix
  ];
  machines.base.nixosState = "25.11";
  machines.base.wifiInterfaceName = "wlp0s13f0u1u4";
  machines.base.acceptRemoteBuilds = true;
  machines.cudaNode.enable = true;
  machines.base.timedOrchJobs = [
    {
      name = "launchpad-sync";
      jobShellScript = pkgs.writeShellScript "launchpad-sync" ''
        export PATH="${
          pkgs.lib.makeBinPath [
            pkgs.git
            pkgs.openssh
          ]
        }:$PATH"
        REPO=$HOME/launchpad
        if [[ -d "$REPO/.git" ]]; then
          cd "$REPO"
          if [[ -n "$(git status --porcelain)" ]]; then
            git add -A
            git commit -m "Auto-commit $(date '+%Y-%m-%d %H:%M:%S')"
          fi
          pull_out=$(git pull --rebase origin master 2>&1)
          if [[ $? -eq 0 ]]; then
            push_out=$(git push origin master 2>&1)
            if [[ $? -eq 0 ]]; then
              logger -t launchpad-sync "Sync complete"
            else
              echo "$push_out" >&2
              logger -t launchpad-sync "Push to master failed"
            fi
          else
            echo "$pull_out" >&2
            git rebase --abort 2>/dev/null
            logger -t launchpad-sync "Rebase conflict detected, manual intervention needed"
          fi
        else
          logger -t launchpad-sync "No git repository found at $REPO, skipping"
        fi
      '';
      timerCfg = {
        OnCalendar = [ "*-*-* 03:00:00" ];
        Persistent = true;
      };
    }
  ];
  networking.hostName = "atorgesen-dell";
}
