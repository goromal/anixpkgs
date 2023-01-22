{
    nixpkgs = builtins.fetchGit {
        url = "git@github.com:NixOS/nixpkgs.git";
        rev = "e2f7be9877cb0851a46279d563abc90c0396253a"; # 12-14-22
        ref = "master";
    };
    nix-ros-overlay = builtins.fetchGit {
        url = "git@github.com:lopsided98/nix-ros-overlay.git";
        rev = "795e67fe0e19118cef94209e4470edc64f13df93";
        ref = "master";
    };
}
