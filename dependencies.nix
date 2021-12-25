{
    nixpkgs = builtins.fetchGit {
        url = "git@github.com:NixOS/nixpkgs.git";
        rev = "b83fd49b13af82fac05b17473ae4bc4e29b4e27d";
        ref = "master";
    };
    nix-ros-overlay = builtins.fetchGit {
        url = "git@github.com:lopsided98/nix-ros-overlay.git";
        rev = "3f30908bc180ecab76d64f71b779c40f8b106949";
        ref = "master";
    };
}