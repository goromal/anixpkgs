{
    nixpkgs = builtins.fetchGit {
        url = "https://github.com/NixOS/nixpkgs";
        rev = "4b7664384c7600dadb4dc8d1708626d073681b40"; # 01-08-23
        ref = "master";
    };
}
