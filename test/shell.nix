let pkgs = import ../default.nix { };
in with pkgs;
mkShell {
  nativeBuildInputs = [ git direnv lorri ];
  buildInputs = [
    make-title
    devshell
    setupws
    listsources
    color-prints
    mp4unite
    scrape
    orchestrator
    fix-perms
    dirgather
    dirgroups
    cpp-helper
  ];
  shellHook = ''
    ${color-prints}/bin/echo_yellow "Entering anixpkgs test shell..."
  '';
}
