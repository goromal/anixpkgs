{ pkgs, config, lib, ... }:
with import ../dependencies.nix;
let
  cfg = config.mods.opts;
  browser-aliases = if cfg.browserExec == null then
    null
  else
    (anixpkgs.callPackage ../../bash-packages/browser-aliases {
      browserExec = cfg.browserExec;
    });
  rcrsyncConfigured = anixpkgs.rcrsync.override { cloudDirs = cfg.cloudDirs; };
  oPathPkgs = lib.makeBinPath [ pkgs.rclone rcrsyncConfigured ];
  launchOrchestratorScript = pkgs.writeShellScriptBin "launch-orchestrator" ''
    PATH=$PATH:/usr/bin:${oPathPkgs} ${anixpkgs.orchestrator}/bin/orchestratord -n 2
  '';
  auto_sync_cloud_dirs =
    builtins.filter (x: !builtins.hasAttr "autosync" x || x.autosync)
    cfg.cloudDirs;
  cloud_dir_list =
    builtins.concatStringsSep " " (map (x: "${x.name}") auto_sync_cloud_dirs);
  launchSyncJobsScript = pkgs.writeShellScriptBin "launch-sync-jobs" ''
    for cloud_dir in ${cloud_dir_list}; do
      ${anixpkgs.orchestrator}/bin/orchestrator sync $cloud_dir
    done
  '';
in {
  home.stateVersion = cfg.homeState;

  home.packages = let
    rcrsync = rcrsyncConfigured;
    authm = anixpkgs.authm.override { inherit rcrsync; };
  in ([
    pkgs.rclone
    authm
    rcrsync
    (anixpkgs.anix-version.override { standalone = cfg.standalone; })
    (anixpkgs.anix-upgrade.override { standalone = cfg.standalone; })
    anixpkgs.goromail
    anixpkgs.manage-gmail
    anixpkgs.gmail-parser
    anixpkgs.wiki-tools
    anixpkgs.task-tools
    anixpkgs.photos-tools
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
    anixpkgs.rcdo
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
  ] ++ (if cfg.standalone == false then [ pkgs.docker pkgs.tmux ] else [ ]));

  systemd.user.services.orchestratord = lib.mkIf cfg.userOrchestrator {
    Unit = { Description = "User-domain Orchestrator daemon"; };
    Service = {
      Type = "simple";
      ExecStart = "${launchOrchestratorScript}/bin/launch-orchestrator";
      Restart = "always";
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services.cloud-dirs-sync = lib.mkIf cfg.cloudAutoSync {
    Unit = { Description = "cloud dirs sync script"; };
    Service = {
      Type = "oneshot";
      ExecStart = "${launchSyncJobsScript}/bin/launch-sync-jobs";
      Restart = "on-failure";
      ReadWritePaths = [ cfg.homeDir ];
    };
  };
  systemd.user.timers.cloud-dirs-sync = lib.mkIf cfg.cloudAutoSync {
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
    plugins = with pkgs.vimPlugins; [
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
    ".anix-meta".text = anixpkgs-meta;
    "records/${records.crypt.name}".source = records.crypt.data;
    ".tmux.conf" = lib.mkIf (cfg.standalone == false) {
      text = ''
        set-option -g default-shell /run/current-system/sw/bin/bash
        set-window-option -g mode-keys vi
        set -g default-terminal "screen-256color"
        set -ga terminal-overrides ',screen-256color:Tc'
      '';
    };
  };
}
