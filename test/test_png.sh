anixdir="$(dirname $PWD)"
export NIX_PATH="anixpkgs=$anixdir:$NIX_PATH"
tmpdir="$anixdir/test/tmpdir"
if [[ -d $tmpdir ]]; then
    rm -rf $tmpdir
fi
mkdir $tmpdir
cd $tmpdir

make-title -c yellow "Testing PNG tools"

# Random PNG generation (determinism check)
png 4444-400-200.random my.png
ckfile -c 5ccd6f61bddaae29a2c2b56a1561a1dd my.png || { echo_red "Unexpected random PNG hash"; exit 1; }
ckfile -c 5ccd6f61bddaae29da2c2b56a1561a1dd my.png && { echo_red "Unexpected random PNG hash check"; exit 1; }

# GIF -> PNG
ffmpeg -f lavfi -i color=red:s=20x20:rate=5 -t 0.4 test.gif 2>/dev/null
png test.gif gif_out.png
[[ -s gif_out.png ]] || { echo_red "GIF to PNG conversion produced no output"; exit 1; }
GIF_PNG_MD5=$(ckfile gif_out.png)
rm gif_out.png && png test.gif gif_out.png
ckfile -c $GIF_PNG_MD5 gif_out.png || { echo_red "GIF to PNG conversion is not deterministic"; exit 1; }

# SVG -> PNG
cat > test.svg << 'SVGEOF'
<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20"><rect width="20" height="20" fill="blue"/></svg>
SVGEOF
png test.svg svg_out.png
[[ -s svg_out.png ]] || { echo_red "SVG to PNG conversion produced no output"; exit 1; }
SVG_PNG_MD5=$(ckfile svg_out.png)
rm svg_out.png && png test.svg svg_out.png
ckfile -c $SVG_PNG_MD5 svg_out.png || { echo_red "SVG to PNG conversion is not deterministic"; exit 1; }

# Cleanup
rm -rf "$tmpdir"
