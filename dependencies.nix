{
    nixpkgs = builtins.fetchGit {
        url = "git@github.com:NixOS/nixpkgs.git";
        rev = "4b7664384c7600dadb4dc8d1708626d073681b40"; # 01-08-23
        ref = "master";
    };
}
