anixdir="$(dirname $PWD)"
export NIX_PATH="anixpkgs=$anixdir:$NIX_PATH"
tmpdir="$anixdir/test/tmpdir"
if [[ -d $tmpdir ]]; then
    rm -rf $tmpdir
fi
mkdir $tmpdir
cd $tmpdir

make-title -c yellow "Testing MP4 tools"

mp4 4444-720-480-100.random my.mp4
ckfile -c 45985c0af6c249485ab6dcdda951d96d my.mp4 || { echo_red "Unexpected random MP4 hash"; exit 1; }
ckfile -c 45985c0af6c249485ab6dcddda951d96d my.mp4 && { echo_red "Unexpected random MP4 hash check"; exit 1; }

# Cleanup
rm -rf "$tmpdir"
