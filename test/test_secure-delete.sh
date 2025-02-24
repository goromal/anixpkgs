anixdir="$(dirname $PWD)"
export NIX_PATH="anixpkgs=$anixdir:$NIX_PATH"
tmpdir="$anixdir/test/tmpdir"
if [[ -d $tmpdir ]]; then
    rm -rf $tmpdir
fi
mkdir $tmpdir
cd $tmpdir

make-title -c yellow "Testing secure delete tool"
cd $tmpdir

dd if=/dev/urandom of=file_1mb_orig bs=1024 count=1024 2>&1 > /dev/null

# cp file_1mb_orig file_
cp file_1mb_orig file_z
cp file_1mb_orig file_l
cp file_1mb_orig file_lz
cp file_1mb_orig file_f
cp file_1mb_orig file_fz

mkdir -p nested_/nest
cp file_1mb_orig nested_/file
cp file_1mb_orig nested_/nest/file

mkdir -p nested_f/nest
cp file_1mb_orig nested_f/file
cp file_1mb_orig nested_f/nest/file

mv file_1mb_orig file_

echo_white "Full randomized deletion"
{ time secure-delete -v file_; } 2> time_
time_=$(cat time_ | grep real | awk '{print $2}' | sed 's/[ms]//g' | tr -d '[:space:]')
echo_white $time_
[[ -f file_ ]] && { echo_red "Failed to delete file"; exit 1; }

echo_white "Full randomized (zeroized) deletion"
{ time secure-delete -vz file_z; } 2> time_z
time_z=$(cat time_z | grep real | awk '{print $2}' | sed 's/[ms]//g' | tr -d '[:space:]')
echo_white $time_z
[[ -f file_z ]] && { echo_red "Failed to delete file"; exit 1; }

echo_white "Half randomized deletion"
{ time secure-delete -vl file_l; } 2> time_l
time_l=$(cat time_l | grep real | awk '{print $2}' | sed 's/[ms]//g' | tr -d '[:space:]')
echo_white $time_l
[[ -f file_l ]] && { echo_red "Failed to delete file"; exit 1; }

if [[ "$time_l" > "$time_" ]]; then
    echo_yellow "Warning: non-monotonically decreasing deletion times"
fi

echo_white "Half randomized (zeroized) deletion"
{ time secure-delete -vlz file_lz; } 2> time_lz
time_lz=$(cat time_lz | grep real | awk '{print $2}' | sed 's/[ms]//g' | tr -d '[:space:]')
echo_white $time_lz
[[ -f file_lz ]] && { echo_red "Failed to delete file"; exit 1; }

echo_white "Insecure deletion"
{ time secure-delete -vf file_f; } 2> time_f
time_f=$(cat time_f | grep real | awk '{print $2}' | sed 's/[ms]//g' | tr -d '[:space:]')
echo_white $time_f
[[ -f file_f ]] && { echo_red "Failed to delete file"; exit 1; }

if [[ "$time_f" > "$time_l" ]]; then
    echo_yellow "Warning: non-monotonically decreasing deletion times"
fi

echo_white "Insecure (zeroized) deletion"
{ time secure-delete -vfz file_fz; } 2> time_fz
time_fz=$(cat time_fz | grep real | awk '{print $2}' | sed 's/[ms]//g' | tr -d '[:space:]')
echo_white $time_fz
[[ -f file_fz ]] && { echo_red "Failed to delete file"; exit 1; }

echo_white "Full randomized recursive deletion"
{ time secure-delete -vr nested_; } 2> time_r
time_r=$(cat time_r | grep real | awk '{print $2}' | sed 's/[ms]//g' | tr -d '[:space:]')
echo_white $time_r
[[ -d nested_ ]] && { echo_red "Failed to delete files"; exit 1; }

echo_white "Insecure recursive deletion"
{ time secure-delete -vrf nested_f; } 2> time_rf
time_rf=$(cat time_rf | grep real | awk '{print $2}' | sed 's/[ms]//g' | tr -d '[:space:]')
echo_white $time_rf
[[ -d nested_f ]] && { echo_red "Failed to delete files"; exit 1; }

if [[ "$time_rf" > "$time_r" ]]; then
    echo_yellow "Warning: insecure recursive deletion took longer than full randomized recursive deletion"
fi

rm -rf "$tmpdir"
