{
    nixpkgs = builtins.fetchGit {
        url = "git@github.com:NixOS/nixpkgs.git";
        rev = "f0f614616f2bd0e6bcf562b0fdf3a9d72ad96830";
        ref = "master";
    };
    nix-ros-overlay = builtins.fetchGit {
        url = "git@github.com:lopsided98/nix-ros-overlay.git";
        rev = "3f30908bc180ecab76d64f71b779c40f8b106949";
        ref = "master";
    };
}