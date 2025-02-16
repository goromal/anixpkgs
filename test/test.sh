exit_code=0

tests=(
    "test_dirstuff.sh"
    "test_ws_tools.sh"
    "test_sunnyside.sh"
    "test_orchestrator.sh"
    "test_fix-perms.sh"
    "test_src_fetch.sh"
    "test_secure-delete.sh"
)

for test in "${tests[@]}"; do
    echo_white -e "\nRunning $test\n"
    bash "$test"
    if [ $? -ne 0 ]; then
        echo_red -e "\n$test FAILED\n"
        exit_code=1
    fi
done

if [ $exit_code -eq 0 ]; then
    echo ""
    make-title -c green "PASSED"
fi

exit $exit_code
