{
    nixpkgs = builtins.fetchGit {
        url = "git@github.com:NixOS/nixpkgs.git";
        rev = "f0f614616f2bd0e6bcf562b0fdf3a9d72ad96830";
        ref = "master";
    };
    nix-ros-overlay = builtins.fetchGit {
        url = "git@github.com:lopsided98/nix-ros-overlay.git";
        rev = "1fb554b5ddcf09c3d109067d9b8976e7382c5413";
        ref = "master";
    };
}
