{ pkgs, config, ... }:
with pkgs;
with lib;
with import ../dependencies.nix { inherit config; };
let cloud_daemon_list =
    (builtins.filter (v: v.daemonmode) (cfg.cloudDirs));
in let
  cfg = config.mods.opts;
  browser-aliases = if cfg.browserExec == null then
    null
  else
    (anixpkgs.callPackage ../../bash-packages/browser-aliases {
      browserExec = cfg.browserExec;
    });
  rcrsyncConfigured = anixpkgs.rcrsync.override {
    cloudDirs = cfg.cloudDirs;
  }; # ^^^^ TODO modify and add modules elsewhere?
  oPathPkgs = makeBinPath [ rclone rcrsyncConfigured ];
  launchOrchestratorScript = writeShellScriptBin "launch-orchestrator" ''
    PATH=$PATH:/usr/bin:${oPathPkgs} ${anixpkgs.orchestrator}/bin/orchestratord -n 2
  '';
  cloud_dir_list = builtins.concatStringsSep " "
    (map (x: "${x.name}") (builtins.filter (v: !v.daemonmode) cfg.cloudDirs));
  # cloud_daemon_list =
  #   (builtins.filter (v: v.daemonmode) (cfg.cloudDirs)); # ^^^^ TODO
  # cloud_daemon_list = (builtins.filter (v: v.daemonmode) ([ # ^^^^ this works...
  #       ({
  #         name = "configs";
  #         cloudname = "dropbox:configs";
  #         dirname = "${cfg.homeDir}/configs";
  #         daemonmode = true;
  #       })
  #       {
  #         name = "secrets";
  #         cloudname = "dropbox:secrets";
  #         dirname = "${cfg.homeDir}/secrets";
  #         daemonmode = true;
  #       }
  #       {
  #         name = "games";
  #         cloudname = "dropbox:games";
  #         dirname = "${cfg.homeDir}/games";
  #         daemonmode = false;
  #       }
  #       {
  #         name = "data";
  #         cloudname = "box:data";
  #         dirname = "${cfg.homeDir}/data";
  #         daemonmode = true;
  #       }
  #       {
  #         name = "documents";
  #         cloudname = "drive:Documents";
  #         dirname = "${cfg.homeDir}/Documents";
  #         daemonmode = true;
  #       }
  #     ]));
  launchSyncJobsScript = writeShellScriptBin "launch-sync-jobs" ''
    for cloud_dir in ${cloud_dir_list}; do
      ${anixpkgs.orchestrator}/bin/orchestrator sync $cloud_dir
    done
  '';
  mkSyncService = { name, cloudname, dirname, homedir }:
    let
      execScript = writeShellScript "execute-sync" ''
        if [ ! -d "${dirname}" ] || [ "$(ls -A ${dirname} 2>/dev/null)" ]; then
            if [ ! -d "${dirname}" ]; then
                echo "Mount directory ${dirname} does not exist. Exiting."
            else
                echo "Mount directory ${dirname} is not empty. Exiting."
            fi
            exit 1
        else
            echo "Mount directory ${dirname} exists and is empty. Continuing..."
        fi
        echo "Mounting "${cloudname} -> ${dirname}..."
        rclone mount --config=${homedir}/.rclone.conf --vfs-cache-mode writes ${cloudname} ${dirname}
      ''; # ^^^^ TODO assuming the location of the rclone conf file...
      stopScript = writeShellScript "stop-sync" ''
        fusermount -u ${dirname}
      '';
    in {
      systemd.user.services."${name}-sync" = {
        Unit.Description = "${name} cloud sync service";
        Unit.After = [ "network-online.target" ];
        Service = {
          Type = "simple";
          ExecStart = "${execScript}/bin/execute-sync";
          ExecStop = "${stopScript}/bin/stop-sync";
          Restart = "always";
          RestartSec = 30;
        };
        Install.WantedBy = [ "default.target" ];
      };
    };
  cloudDaemonServices = (map (x:
    (mkSyncService {
      name = x.name;
      cloudname = x.cloudname;
      dirname = x.dirname;
      homedir = cfg.homeDir;
    })) cloud_daemon_list);

in (foldl' (acc: set: recursiveUpdate acc set) ({
  home.stateVersion = cfg.homeState;

  home.packages = let
    rcrsync = rcrsyncConfigured;
    authm = anixpkgs.authm.override { inherit rcrsync; };
  in ([
    rclone
    authm
    rcrsync
    (anixpkgs.anix-version.override { standalone = cfg.standalone; })
    (anixpkgs.anix-upgrade.override {
      standalone = cfg.standalone;
      inherit browser-aliases;
    })
    anixpkgs.goromail
    anixpkgs.manage-gmail
    anixpkgs.gmail-parser
    anixpkgs.wiki-tools
    anixpkgs.task-tools
    anixpkgs.book-notes-sync
    anixpkgs.budget_report
    anixpkgs.color-prints
    anixpkgs.fix-perms
    anixpkgs.secure-delete
    anixpkgs.sunnyside
    anixpkgs.make-title
    anixpkgs.pb
    anixpkgs.dirgroups
    anixpkgs.dirgather
    anixpkgs.fixfname
    anixpkgs.nix-deps
    anixpkgs.nix-diffs
    anixpkgs.orchestrator
    anixpkgs.rankserver-cpp
    anixpkgs.stampserver
    anixpkgs.gantter
    anixpkgs.md2pdf
    anixpkgs.notabilify
    anixpkgs.code2pdf
    anixpkgs.abc
    anixpkgs.doku
    anixpkgs.epub
    anixpkgs.gif
    anixpkgs.md
    anixpkgs.mp3
    anixpkgs.mp4
    anixpkgs.mp4unite
    anixpkgs.pdf
    anixpkgs.png
    anixpkgs.svg
    anixpkgs.zipper
    anixpkgs.scrape
  ] ++ (if cfg.standalone == false then [ docker tmux ] else [ ]));

  systemd.user.services.orchestratord = mkIf cfg.userOrchestrator {
    Unit = { Description = "User-domain Orchestrator daemon"; };
    Service = {
      Type = "simple";
      ExecStart = "${launchOrchestratorScript}/bin/launch-orchestrator";
      Restart = "always";
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services.cloud-dirs-sync = mkIf cfg.cloudAutoSync {
    Unit = { Description = "cloud dirs sync script"; };
    Service = {
      Type = "oneshot";
      ExecStart = "${launchSyncJobsScript}/bin/launch-sync-jobs";
      Restart = "on-failure";
      ReadWritePaths = [ cfg.homeDir ];
    };
  };
  systemd.user.timers.cloud-dirs-sync = mkIf cfg.cloudAutoSync {
    Unit = { Description = "cloud dirs sync timer"; };
    Timer = {
      OnBootSec = "${builtins.toString cfg.cloudAutoSyncInterval}m";
      OnUnitActiveSec = "${builtins.toString cfg.cloudAutoSyncInterval}m";
      Unit = "cloud-dirs-sync.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  programs.vim = {
    enable = true;
    extraConfig = ''
      if has('gui_running')
          set guifont=Iosevka
      endif
      set expandtab
      " open NERDTree automatically if no file specified
      "autocmd StdinReadPre * let s:std_in=1
      "autocmd VimEnter * if argc() == 0 && !exists("s:std_in") | NERDTree | endif
      " open NERDTree on Ctrl-n
      map <C-n> :NERDTreeToggle<CR>
      set wildignore+=*/node_modules/*,_site,*/__pycache__/,*/venv/*,*/target/*,*/.vim$,\~$,*/.log,*/.aux,*/.cls,*/.aux,*/.bbl,*/.blg,*/.fls,*/.fdb*/,*/.toc,*/.out,*/.glo,*/.log,*/.ist,*/.fdb_latexmk
      set encoding=utf-8
      set termguicolors
      set background=dark
      let g:mix_format_on_save = 1
      let g:mix_format_options = '--check-equivalent'
    '';
    settings = { number = true; };
    plugins = with vimPlugins; [
      vim-elixir
      sensible
      vim-airline
      The_NERD_tree
      fugitive
      vim-abolish
      command-t
    ];
  };

  home.file = with anixpkgs.pkgData; {
    ".anix-version".text =
      if local-build then "Local Build" else "v${anixpkgs-version}";
    "records/${records.crypt.name}".source = records.crypt.data;
    ".tmux.conf" = mkIf (cfg.standalone == false) {
      text = ''
        set-option -g default-shell /run/current-system/sw/bin/bash
        set-window-option -g mode-keys vi
        set -g default-terminal "screen-256color"
        set -ga terminal-overrides ',screen-256color:Tc'
      '';
    };
  };

}) cloudDaemonServices)
