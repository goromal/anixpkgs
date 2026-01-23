{ pkgs, config, lib, ... }:
with import ../dependencies.nix;
let cfg = config.mods.opts;
in {
  home.packages = [
    pkgs.direnv
    anixpkgs.aapis-grpcurl
    anixpkgs.flake-update
    anixpkgs.git-cc
    anixpkgs.git-shortcuts
    anixpkgs.setupws
    anixpkgs.listsources
    anixpkgs.pkgshell
    (anixpkgs.devshell.override { editorName = cfg.editor; })
    (pkgs.writeShellScriptBin "dsd" ''
      devshell $@ --run dev
    '')
    anixpkgs.cpp-helper
    anixpkgs.py-helper
    anixpkgs.rust-helper
    anixpkgs.makepyshell
    pkgs.gh
    pkgs.universal-ctags
    unstable.claude-code
    (pkgs.writeShellScriptBin "claude-setup" ''
      if ! command -v claude &> /dev/null; then
        echo_red "Error: claude not found in PATH"
        exit 1
      fi
      echo_yellow "Installing claude plugins..."
      claude plugin marketplace add DevonMorris/claude-ctags 2>/dev/null || true
      claude plugin install claude-ctags@claude-ctags 2>/dev/null || true
      claude plugin install code-review@claude-plugins-official
      claude plugin install frontend-design@claude-plugins-official
      claude plugin install github@claude-plugins-official
      claude plugin install feature-dev@claude-plugins-official
      claude plugin install pr-review-toolkit@claude-plugins-official
      echo_green "Done! Verify installed plugins with \"claude plugin list\""
      echo_yellow "Other setup..."
      gh auth login
    '')
    # ^^^^ ✘ Failed to install plugin "code-review@claude-plugins-official": Failed to update settings: Failed to read raw settings from /data/andrew/.claude/settings.json: Error: EROFS: read-only file system, open '/nix/store/bx0r3qc2vas9h64fwvpfh09wjyzldb6a-home-manager-files/.claude/settings.json'

  ];

  programs.git = {
    package = pkgs.gitAndTools.gitFull;
    enable = true;
    userName = "Andrew Torgesen";
    userEmail = "andrew.torgesen@gmail.com";
    aliases = {
      aa = "add -A";
      cm = "commit -m";
      co = "checkout";
      cp = "cherry-pick";
      s = "status";
      d = "diff";
    };
    extraConfig = {
      init = { defaultBranch = "master"; };
      push = { default = "current"; };
      pull = { default = "current"; };
    };
  };

  services.lorri.enable = true;

  programs.vim.plugins = lib.mkIf (cfg.standalone == false)
    (with pkgs.vimPlugins; [ vim-gitgutter YouCompleteMe ]);
}
