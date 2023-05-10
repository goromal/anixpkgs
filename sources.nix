{
    # TODO replace with flake.nix
    anixdata = builtins.fetchGit {
        url = "git@github.com:goromal/anixdata.git";
        rev = "13b1b596e5c8db91c6e52e09cdd3b79f31b400a6";
        ref = "master";
    };
    aapis = builtins.fetchGit {
        url = "git@github.com:goromal/aapis.git";
        rev = "d6011aac0c36274c544ecf60ac98e10f717f9011";
        ref = "master";
    };
    ceres-factors = builtins.fetchGit {
        url = "git@github.com:goromal/ceres-factors.git";
        rev = "ee861da2f7f756046703cee2620ffdea7d71a5be";
        ref = "main";
    };
    crowcpp = builtins.fetchGit {
        url = "git@github.com:goromal/Crow.git";
        rev = "8405788649538e5a45c791af5db5df5e171a8844";
        ref = "master";
    };
    manif-geom-cpp = builtins.fetchGit {
        url = "git@github.com:goromal/manif-geom-cpp.git";
        rev = "4d4c8781eaa5509a229ce6e04f751350cd0eb707";
        ref = "master";
    };
    mfn = builtins.fetchGit {
        url = "git@github.com:goromal/mfn.git";
        rev = "a46db67cb711f6d2033436114a2e9dbb9b2e87b3";
        ref = "master";
    };
    mscpp = builtins.fetchGit {
        url = "git@github.com:goromal/mscpp.git";
        rev = "c2560bf1259965110c610a7d71bdd04a4076ce93";
        ref = "master";
    };
    rankserver-cpp = builtins.fetchGit {
        url = "git@github.com:goromal/rankserver-cpp.git";
        rev = "4b0b1f4295e3e3ad45a84e6323fe4260964b2044";
        ref = "master";
    };
    secure-delete = builtins.fetchGit {
        url = "git@github.com:goromal/secure-delete.git";
        rev = "a114f5b0c24c2616b22f25be39430793587bd2fd";
        ref = "master";
    };
    signals-cpp = builtins.fetchGit {
        url = "git@github.com:goromal/signals-cpp.git";
        rev = "5fca7190b13b4d357755e54e7b161d94d3990e57";
        ref = "master";
    };
    sorting = builtins.fetchGit {
        url = "git@github.com:goromal/sorting.git";
        rev = "b254d4c895afcbc551fb0b55eefe9c9cec388d80";
        ref = "master";
    };
    evil-hangman = builtins.fetchGit {
        url = "git@github.com:goromal/evil-hangman.git";
        rev = "198c067dd33fe5c9b77685a8b2ddd059c9316923";
        ref = "master";
    };
    simple-image-editor = builtins.fetchGit {
        url = "git@github.com:goromal/simple-image-editor.git";
        rev = "969fc55b9607f2d9fff549307ad37b6ea67b4a3f";
        ref = "master";
    };
    spelling-corrector = builtins.fetchGit {
        url = "git@github.com:goromal/spelling-corrector.git";
        rev = "d930ce4ea14770822f0dcb24f00884593bc9918f";
        ref = "master";
    };
    book-notes-sync = builtins.fetchGit {
        url = "git@github.com:goromal/book-notes-sync.git";
        rev = "39d17230dad81febac4ee8f2c3ebdd5d58e70b9f";
        ref = "master";
    };
    find_rotational_conventions = builtins.fetchGit {
        url = "https://gist.github.com/fb15f44150ca4e0951acaee443f72d3e.git";
        rev = "f783b777f1c6dcea21a7a1d30519be2f56a810c3";
        ref = "main";
    };
    geometry = builtins.fetchGit {
        url = "git@github.com:goromal/geometry.git";
        rev = "a5a5ed08b0daf7ef91b4ed342a9e407225b12ad0";
        ref = "main";
    };
    gmail-parser = builtins.fetchGit {
        url = "git@github.com:goromal/gmail_parser.git";
        rev = "de149ce863c7742e50a92000a5f3013159d5129e";
        ref = "master";
    };
    makepyshell = builtins.fetchGit {
        url = "https://gist.github.com/e64b6bdc8a176c38092e9bde4c434d31.git";
        rev = "9006a586bfc6233ea069c2c6975e57e42f470a17";
        ref = "main";
    };
    mavlog-utils = builtins.fetchGit {
        url = "git@github.com:goromal/mavlog-utils.git";
        rev = "3b108eeabe2c46aa5d1e160d5f53d94c5abb50eb";
        ref = "master";
    };
    mesh-plotter = builtins.fetchGit {
        url = "git@github.com:goromal/mesh-plotter.git";
        rev = "e973dd7abb45e64c509f712350399bcd2da372b5";
        ref = "master";
    };
    pyceres = builtins.fetchGit {
        url = "git@github.com:Edwinem/ceres_python_bindings.git";
        rev = "2106d043bce37adcfef450dd23d3005480948c37";
        ref = "master";
    };
    pyceres_factors = builtins.fetchGit {
        url = "git@github.com:goromal/pyceres_factors.git";
        rev = "54f9a1dbb4fb9a5b74a72bb1377575bd0016d3c1";
        ref = "main";
    };
    pysignals = builtins.fetchGit {
        url = "git@github.com:goromal/pysignals.git";
        rev = "714c5ea42366292d9528fa6aee34d530ac52929c";
        ref = "master";
    };
    pysorting = builtins.fetchGit {
        url = "git@github.com:goromal/pysorting.git";
        rev = "ca0439d63607990160c29a1c2d1e6eed450ac98f";
        ref = "master";
    };
    python-dokuwiki = builtins.fetchGit {
        url = "git@github.com:fmenabe/python-dokuwiki.git";
        ref = "refs/tags/1.3.3";
    };
    scrape = builtins.fetchGit {
        url = "git@github.com:goromal/scrape.git";
        rev = "78949266ffb0a15f396004865631a44c84ac7257";
        ref = "master";
    };
    trafficsim = builtins.fetchGit {
        url = "https://gist.github.com/c37629235750b65b9d0ec0e17456ee96.git";
        rev = "bd0d6741dbbd85d2951739c351dd501ac7e9af97";
        ref = "main";
    };
    wiki-tools = builtins.fetchGit {
        url = "git@github.com:goromal/wiki-tools.git";
        rev = "de3409a68fc8865c3d4902e2c6442555b77471f3";
        ref = "master";
    };
    xv-lidar-rs = builtins.fetchGit {
        url = "git@github.com:goromal/xv-lidar-rs.git";
        rev = "6dea171e8871e660253bc12ba9f030a725162d1b";
        ref = "master";
    };
}
