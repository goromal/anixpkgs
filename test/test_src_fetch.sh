anixdir="$(dirname $PWD)"
export NIX_PATH="anixpkgs=$anixdir:$NIX_PATH"
tmpdir="$anixdir/test/tmpdir"
if [[ -d $tmpdir ]]; then
    rm -rf $tmpdir
fi
mkdir $tmpdir
cd $tmpdir

make-title -c yellow "Testing source fetcher"
cd $tmpdir
mkdir pkg_srcs
cd pkg_srcs
nix-build -E 'with (import (../../../default.nix) {}); pkgsSource { local = false; ref = "refs/tags/v2.2.0"; }' -o src1
if [[ -z $(cat src1/ANIX_VERSION | grep 2\.2\.0) ]]; then
    echo_red "Failed to fetch anixpkgs 2.2.0 by tag; received $(cat src1/ANIX_VERSION)"
    exit 1
fi
nix-build -E 'with (import (../../../default.nix) {}); pkgsSource { local = false; rev = "d393a9ba7d5b9b40fb2f774a2c216002a89810c5"; }' -o src2
if [[ -z $(cat src2/ANIX_VERSION | grep 2\.1\.1) ]]; then
    echo_red "Failed to fetch anixpkgs 2.1.1 by commit; received $(cat src2/ANIX_VERSION)"
    exit 1
fi
nix-build -E 'with (import (../../../default.nix) {}); pkgsSource { local = false; ref = "refs/heads/REGRESSION_TEST"; }' -o src3
if [[ -z $(cat src3/ANIX_VERSION | grep TEST_VERSION) ]]; then
    echo_red "Failed to fetch anixpkgs TEST_VERSION by branch; received $(cat src3/ANIX_VERSION)"
    exit 1
fi

# Cleanup
rm -rf "$tmpdir"
