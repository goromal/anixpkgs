{
    nixpkgs = builtins.fetchGit {
        url = "git@github.com:NixOS/nixpkgs.git";
        rev = "faf0031868410414c5c11bae8a374de8af2ed68b";
        ref = "master";
    };
    nix-ros-overlay = builtins.fetchGit {
        url = "git@github.com:lopsided98/nix-ros-overlay.git";
        rev = "795e67fe0e19118cef94209e4470edc64f13df93";
        ref = "master";
    };
}
