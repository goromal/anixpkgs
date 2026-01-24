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
      ${lib.concatMapStringsSep "\n      " (marketplace:
        "claude plugin marketplace add ${marketplace} 2>/dev/null || true")
      cfg.claudeMarketplaces}
      ${lib.concatMapStringsSep "\n      "
      (plugin: "claude plugin install ${plugin} 2>/dev/null || true")
      cfg.claudePlugins}
      echo_green "Done! Verify installed plugins with \"claude plugin list\""

      echo_yellow "Other setup..."
      read -p "Proceed with gh CLI setup? (y|n) " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        gh auth login
      fi
    '')
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

  home.file.".claude/settings.json".text = let
    pluginsObj = builtins.listToAttrs (map (plugin: {
      name = plugin;
      value = true;
    }) cfg.claudePlugins);
    baseConfig = { enabledPlugins = pluginsObj; };
    mergedConfig = baseConfig // cfg.extraClaudeSettings;
  in builtins.toJSON mergedConfig;
}
