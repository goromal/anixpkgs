{
    nixpkgs = builtins.fetchGit {
        url = "git@github.com:NixOS/nixpkgs.git";
        rev = "4d2b37a84fad1091b9de401eb450aae66f1a741e"; # initial cut
        ref = "release-22.11";
    };
    nix-ros-overlay = builtins.fetchGit {
        url = "git@github.com:lopsided98/nix-ros-overlay.git";
        rev = "795e67fe0e19118cef94209e4470edc64f13df93";
        ref = "master";
    };
}
