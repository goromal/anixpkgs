let
  pkgs = import ../default.nix { };
  standalone-anix-upgrade = pkgs.anix-upgrade.override { standalone = true; };
in
with pkgs;
mkShell {
  ANIX_UPGRADE_STANDALONE_BIN = "${standalone-anix-upgrade}/bin/anix-upgrade";
  nativeBuildInputs = [
    git
    direnv
    lorri
  ];
  buildInputs = [
    anix-upgrade
    make-title
    devshell
    setupws
    listsources
    color-prints
    mp4unite
    mp3unite
    mp3separate
    mp4separate
    scrape
    orchestrator
    fix-perms
    dirgather
    dirgroups
    cpp-helper
    pkgshell
    sunnyside
    sread
    swrite
    secure-delete
    time
    png
    mp3
    mp4
    gif
    ckfile
    ffmpeg
  ];
  shellHook = ''
    ${color-prints}/bin/echo_yellow "Entering anixpkgs test shell..."
  '';
}
