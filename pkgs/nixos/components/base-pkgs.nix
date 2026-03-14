{
  pkgs,
  config,
  lib,
  ...
}:
with import ../dependencies.nix;
let
  cfg = config.mods.opts;
  browser-aliases =
    if cfg.browserExec == null then
      null
    else
      (anixpkgs.callPackage ../../bash-packages/browser-aliases {
        browserExec = cfg.browserExec;
      });
  rcrsyncConfigured = anixpkgs.rcrsync.override {
    cloudDirs = cfg.cloudDirs;
    homeDir = cfg.homeDir;
    rcloneCfg = "${cfg.homeDir}/.config/rclone/rclone.conf";
  };
  oPathPkgs = lib.makeBinPath [
    pkgs.rclone
    rcrsyncConfigured
  ];
  launchOrchestratorScript = pkgs.writeShellScriptBin "launch-orchestrator" ''
    PATH=$PATH:/usr/bin:${oPathPkgs} ${anixpkgs.orchestrator}/bin/orchestratord -n 2 \
      ${if cfg.enableMetrics then "--statsd-port ${builtins.toString service-ports.statsd}" else ""}
  '';
  atsRunScript = pkgs.writeShellScriptBin "atsrun" ''
    words=""
    for word in "$@"; do
      words+="$word "
    done
    words=''${words% }
    ${anixpkgs.rcdo}/bin/rcdo "andrew@$(cat ~/secrets/ats/i.txt):$(${anixpkgs.sread}/bin/sread ~/secrets/ats/p.txt.tyz)" "$words" remote
  '';
in
{
  home.stateVersion = cfg.homeState;

  home.packages =
    let
      rcrsync = rcrsyncConfigured;
      authm = anixpkgs.authm.override { inherit rcrsync; };
    in
    (
      [
        pkgs.rclone
        authm
        rcrsync
        (anixpkgs.anix-version.override { standalone = cfg.standalone; })
        (anixpkgs.anix-upgrade.override { standalone = cfg.standalone; })
        anixpkgs.goromail
        anixpkgs.manage-gmail
        anixpkgs.gmail-parser
        anixpkgs.local-ssh-proxy
        anixpkgs.wiki-tools
        anixpkgs.task-tools
        anixpkgs.photos-tools
        anixpkgs.book-notes-sync
        anixpkgs.budget_report
        anixpkgs.surveys_report
        anixpkgs.ckfile
        anixpkgs.color-prints
        anixpkgs.fix-perms
        anixpkgs.secure-delete
        anixpkgs.sunnyside
        anixpkgs.sread
        anixpkgs.swrite
        anixpkgs.make-title
        anixpkgs.pb
        anixpkgs.dirgroups
        anixpkgs.dirgather
        anixpkgs.fixfname
        anixpkgs.nix-deps
        anixpkgs.nix-diffs
        anixpkgs.orchestrator
        anixpkgs.daily_tactical_server
        anixpkgs.rankserver-cpp
        anixpkgs.stampserver
        anixpkgs.rcdo
        atsRunScript
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
      ]
      ++ (
        if cfg.standalone == false then
          [
            pkgs.docker
            pkgs.tmux
          ]
        else
          [ ]
      )
    );

  systemd.user.services.orchestratord = lib.mkIf cfg.userOrchestrator {
    Unit = {
      Description = "User-domain Orchestrator daemon";
    };
    Service = {
      Type = "simple";
      ExecStart = "${launchOrchestratorScript}/bin/launch-orchestrator";
      Restart = "always";
    };
    Install.WantedBy = [ "default.target" ];
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
    settings = {
      number = true;
    };
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
    ".anix-version".text = if local-build then "Local Build" else "v${anixpkgs-version}";
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
