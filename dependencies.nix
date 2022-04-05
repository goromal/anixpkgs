{
    nixpkgs = builtins.fetchGit {
        url = "git@github.com:NixOS/nixpkgs.git";
        rev = "2774f31f40ddef84cc658dd4c15912a08a68becd";
        ref = "master";
    };
    nix-ros-overlay = builtins.fetchGit {
        url = "git@github.com:lopsided98/nix-ros-overlay.git";
        rev = "3f30908bc180ecab76d64f71b779c40f8b106949";
        ref = "master";
    };
}