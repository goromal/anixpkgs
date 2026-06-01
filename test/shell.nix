let
  pkgs = import ../default.nix { };
in
with pkgs;
mkShell {
  nativeBuildInputs = [
    git
    direnv
    lorri
  ];
  buildInputs = [
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
    orchestrator-cpp
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
    ckfile
    ffmpeg
  ];
  shellHook = ''
    ${color-prints}/bin/echo_yellow "Entering anixpkgs test shell..."
  '';
}
