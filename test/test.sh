exit_code=0

# Tests that transcode through an orchestratord are CPU-heavy and poll their
# daemon with a fixed number of tries, so they run one at a time in their own
# lane (longest first) instead of starving each other.
transcode_tests=(
    "test_vacuum.sh"
    "test_orchestrator.sh"
    "test_png.sh"
)
# Everything else shares the remaining TEST_JOBS - 1 slots, longest first.
tests=(
    "test_ws_tools.sh"
    "test_secure-delete.sh"
    "test_mp4.sh"
    "test_no_ifd.sh"
    "test_src_fetch.sh"
    "test_anix_upgrade.sh"
    "test_dirstuff.sh"
    "test_sunnyside.sh"
    "test_mp3.sh"
    "test_mp3unite_separate.sh"
    "test_mp4separate.sh"
    "test_fix-perms.sh"
)

# Each test gets its own TEST_TMPDIR, and the orchestrator-backed tests use
# distinct ports. Logs print afterward in list order.
max_jobs=${TEST_JOBS:-$(nproc)}
logdir=$(mktemp -d)
mkdir -p "$PWD/tmpdir"
run_test() {
    local test=$1 start=$SECONDS
    TEST_TMPDIR="$PWD/tmpdir/${test%.sh}" bash "$test" >"$logdir/$test.log" 2>&1
    echo $? >"$logdir/$test.rc"
    echo $(( SECONDS - start )) >"$logdir/$test.secs"
}

(
    for test in "${transcode_tests[@]}"; do
        run_test "$test"
    done
) &
for test in "${tests[@]}"; do
    while (( $(jobs -rp | wc -l) >= max_jobs )); do
        wait -n
    done
    run_test "$test" &
done
wait

for test in "${transcode_tests[@]}" "${tests[@]}"; do
    [[ -n "$GITHUB_ACTIONS" ]] && echo "::group::$test"
    echo_white -e "\nRunning $test ($(cat "$logdir/$test.secs")s)\n"
    cat "$logdir/$test.log"
    [[ -n "$GITHUB_ACTIONS" ]] && echo "::endgroup::"
    if [ "$(cat "$logdir/$test.rc")" -ne 0 ]; then
        echo_red -e "\n$test FAILED\n"
        exit_code=1
    fi
done
rm -rf "$logdir"

if [ $exit_code -eq 0 ]; then
    echo ""
    make-title -c green "PASSED"
fi

exit $exit_code
