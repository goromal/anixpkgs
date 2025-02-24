anixdir="$(dirname $PWD)"
export NIX_PATH="anixpkgs=$anixdir:$NIX_PATH"
tmpdir="$anixdir/test/tmpdir"
if [[ -d $tmpdir ]]; then
    rm -rf $tmpdir
fi
mkdir $tmpdir
cd $tmpdir

make-title -c yellow "Testing fix-perms"
cd $tmpdir
for dir_desc in fp_test/.ssh/domain fp_test/reg/reg2; do
    mkdir -p $dir_desc
    chmod 777 $dir_desc
done
for file_desc in fp_test/.ssh/private_key fp_test/.ssh/config fp_test/.ssh/private_key.pub \
  fp_test/.ssh/domain/private_key fp_test/reg/file1 fp_test/reg/reg2/file2; do
    touch $file_desc
    chmod 664 $file_desc
done
fix-perms fp_test/reg && cd fp_test/.ssh && fix-perms . && cd ..
[[ "$(stat -c '%a' .ssh/private_key)" ==  "600" ]] || { echo_red "Private SSH key granted incorrect permissions"; exit 1; }
[[ "$(stat -c '%a' .ssh/private_key.pub)" == "644" ]] || { echo_red "Public SSH key granted incorrect permissions"; exit 1; }
[[ "$(stat -c '%a' .ssh/domain)" == "700" ]] || { echo_red "SSH directory granted incorrect permissions"; exit 1; }
[[ "$(stat -c '%a' .ssh/domain/private_key)" == "600" ]] || { echo_red "SSH nested private key granted incorrect permissions"; exit 1; }
[[ "$(stat -c '%a' reg/reg2/file2)" == "644" ]] || { echo_red "Nested file granted incorrect permissions"; exit 1; }
[[ "$(stat -c '%a' reg/reg2)" == "755" ]] || { echo_red "Directory granted incorrect permissions"; exit 1; }

# Cleanup
rm -rf "$tmpdir"
