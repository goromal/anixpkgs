{
    nixpkgs = builtins.fetchGit {
        url = "git@github.com:NixOS/nixpkgs.git";
        rev = "4b7664384c7600dadb4dc8d1708626d073681b40"; # 01-08-23
        ref = "master";
    };
    nix-ros-overlay = builtins.fetchGit {
        url = "git@github.com:lopsided98/nix-ros-overlay.git";
        rev = "795e67fe0e19118cef94209e4470edc64f13df93";
        ref = "master";
    };
}
