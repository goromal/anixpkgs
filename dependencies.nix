{
    nixpkgs = builtins.fetchGit {
        url = "git@github.com:NixOS/nixpkgs.git";
        rev = "076d365c8022c9fc87c476ecdd58be1bc30e83ab";
        ref = "master";
    };
    nix-ros-overlay = builtins.fetchGit {
        url = "git@github.com:lopsided98/nix-ros-overlay.git";
        rev = "795e67fe0e19118cef94209e4470edc64f13df93";
        ref = "master";
    };
}
