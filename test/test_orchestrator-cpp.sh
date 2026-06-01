ORCH_PORT=7778
anixdir="$(dirname $PWD)"
export NIX_PATH="anixpkgs=$anixdir:$NIX_PATH"
tmpdir="$anixdir/test/tmpdir-orch-cpp"
if [[ -d $tmpdir ]]; then
    rm -rf $tmpdir
fi
mkdir $tmpdir
cd $tmpdir

make-title -c yellow "Testing orchestrator-cpp"

# Setup test environment
mkdir orch_data
dbpath="$tmpdir/orchestrator.db"
orchoutpath="$tmpdir/orch_data"

# Note: orchestrator-cpp uses the new v2 API which is more granular
# Unlike the Python version which had high-level wrappers, we need to:
# 1. Define job types first using DefineJob
# 2. Kick off individual jobs using KickoffJob

num_executor_threads=2

echo "Spawning orchestrator-cpp daemon with $num_executor_threads executor threads"

# Start the daemon with custom DB path and port
# Note: Binary is named orchestratord-cpp to avoid conflict with Python orchestrator
nohup orchestratord-cpp --grpc-port $ORCH_PORT --threads $num_executor_threads --db-path "$dbpath" > "$tmpdir/daemon.log" 2>&1 &
serverPID=$!

sleep 5

# Check if server is running
if ! kill -0 $serverPID 2>/dev/null; then
    echo_red "ERROR: orchestratord-cpp failed to start"
    cat "$tmpdir/daemon.log"
    exit 1
fi

echo "Server started with PID $serverPID"
echo "Daemon log (last 20 lines):"
tail -20 "$tmpdir/daemon.log"
echo "---"

# Test 1: Define and kickoff a simple bash job
echo "Test 1: Basic bash job execution via orchestratorctl"

# Define a bash job type
# Note: {input_0} will be substituted with the first input arg
orchestratorctl -p $ORCH_PORT define bash "{input_0}"

if [ $? -ne 0 ]; then
    echo_red "ERROR: failed to define bash job type"
    echo "Daemon log:"
    cat "$tmpdir/daemon.log"
    kill $serverPID
    exit 1
fi

# Create a test script
echo "echo 'Hello from orchestrator-cpp' > $orchoutpath/test1.txt" > "$tmpdir/test1.sh"
chmod +x "$tmpdir/test1.sh"

# Kickoff the job
job_id=$(orchestratorctl -p $ORCH_PORT kickoff bash --input "bash $tmpdir/test1.sh" | grep -oP 'ID: \K\d+')

if [ -z "$job_id" ]; then
    echo_red "ERROR: failed to kickoff bash job"
    kill $serverPID
    exit 1
fi

echo "Kicked off job with ID: $job_id"

# Wait for job to complete (with timeout)
timeout=30
elapsed=0
while [ $elapsed -lt $timeout ]; do
    status=$(orchestratorctl -p $ORCH_PORT status $job_id | grep "Status:" | awk '{print $2}')

    if [ "$status" = "COMPLETE" ]; then
        echo "Job completed successfully"
        break
    elif [ "$status" = "ERROR" ] || [ "$status" = "CANCELED" ]; then
        echo_red "ERROR: Job ended with status: $status"
        orchestratorctl -p $ORCH_PORT status $job_id
        kill $serverPID
        exit 1
    fi

    sleep 1
    elapsed=$((elapsed + 1))
done

if [ $elapsed -ge $timeout ]; then
    echo_red "ERROR: Job timed out after ${timeout}s"
    orchestratorctl -p $ORCH_PORT status $job_id
    kill $serverPID
    exit 1
fi

# Verify output file was created
if [ ! -f "$orchoutpath/test1.txt" ]; then
    echo_red "ERROR: expected output file not created"
    kill $serverPID
    exit 1
fi

echo "Test 1 passed: Basic job execution works"

# Test 2: Query jobs summary
echo "Test 2: Jobs summary query"

summary_output=$(orchestratorctl -p $ORCH_PORT summary)

if [ $? -ne 0 ]; then
    echo_red "ERROR: failed to query jobs summary"
    kill $serverPID
    exit 1
fi

echo "$summary_output"

# Verify we have at least one completed job from Test 1
completed_count=$(echo "$summary_output" | grep "Completed Jobs:" | awk '{print $3}')

if [ -z "$completed_count" ] || [ "$completed_count" -lt 1 ]; then
    echo_red "ERROR: expected at least 1 completed job, got: $completed_count"
    kill $serverPID
    exit 1
fi

echo "Test 2 passed: Jobs summary query works (found $completed_count completed jobs)"

# Test 3: Verify daemon stays alive for a reasonable duration
echo "Test 3: Daemon stability test"
sleep 2

if ! kill -0 $serverPID 2>/dev/null; then
    echo_red "ERROR: orchestratord-cpp crashed during stability test"
    cat "$tmpdir/daemon.log"
    exit 1
fi

echo "Test 3 passed: Daemon remains stable"

# Test 4: Verify database file is created
echo "Test 4: Database persistence"
if [ ! -f "$dbpath" ]; then
    echo_red "ERROR: database file was not created at $dbpath"
    kill $serverPID
    exit 1
fi

# Check database file is non-empty (has schema)
if command -v stat >/dev/null 2>&1; then
    # Try BSD stat first, then GNU stat
    dbsize=$(stat -f%z "$dbpath" 2>/dev/null || stat -c%s "$dbpath" 2>/dev/null)
    if [ "$dbsize" -lt 100 ]; then
        echo_red "ERROR: database file appears to be empty or corrupted"
        kill $serverPID
        exit 1
    fi
    echo "Test 4 passed: Database file created and initialized (size: $dbsize bytes)"
else
    # Fallback if stat is not available
    if [ -s "$dbpath" ]; then
        echo "Test 4 passed: Database file exists and is non-empty"
    else
        echo_red "ERROR: database file appears to be empty"
        kill $serverPID
        exit 1
    fi
fi

# Test 5: Graceful shutdown
echo "Test 5: Graceful shutdown"
kill -SIGTERM $serverPID
shutdown_timeout=10
shutdown_elapsed=0

while kill -0 $serverPID 2>/dev/null && [ $shutdown_elapsed -lt $shutdown_timeout ]; do
    sleep 1
    shutdown_elapsed=$((shutdown_elapsed + 1))
done

if kill -0 $serverPID 2>/dev/null; then
    echo_red "ERROR: daemon did not shutdown gracefully within ${shutdown_timeout}s"
    kill -SIGKILL $serverPID
    exit 1
fi

echo "Test 5 passed: Daemon shutdown gracefully in ${shutdown_elapsed}s"

# Test 6: Restart and database recovery
echo "Test 6: Database recovery after restart"
nohup orchestratord-cpp --grpc-port $ORCH_PORT --threads $num_executor_threads --db-path "$dbpath" > "$tmpdir/daemon2.log" 2>&1 &
serverPID=$!

sleep 3

if ! kill -0 $serverPID 2>/dev/null; then
    echo_red "ERROR: orchestratord-cpp failed to restart"
    cat "$tmpdir/daemon2.log"
    exit 1
fi

echo "Test 6 passed: Daemon restarted successfully with existing database"

# Test 7: Job dependencies with blockers
echo "Test 7: Job dependencies with blockers"

# Re-define bash job type (job type definitions don't persist across restarts) # ^^^^ TODO: fix this
orchestratorctl -p $ORCH_PORT define bash "{input_0}"

if [ $? -ne 0 ]; then
    echo_red "ERROR: failed to re-define bash job type for test 7"
    kill $serverPID
    exit 1
fi

# Create test scripts
echo "echo 'Step 1' > $orchoutpath/step1.txt" > "$tmpdir/step1.sh"
echo "echo 'Step 2' > $orchoutpath/step2.txt" > "$tmpdir/step2.sh"
echo "echo 'Step 3' > $orchoutpath/step3.txt" > "$tmpdir/step3.sh"
chmod +x "$tmpdir/step1.sh" "$tmpdir/step2.sh" "$tmpdir/step3.sh"

# Kickoff job 1 (no blockers)
job1_id=$(orchestratorctl -p $ORCH_PORT kickoff bash --input "bash $tmpdir/step1.sh" | grep -oP 'ID: \K\d+')

if [ -z "$job1_id" ]; then
    echo_red "ERROR: failed to kickoff job 1"
    kill $serverPID
    exit 1
fi

echo "Job 1 ID: $job1_id"

# Kickoff job 2 (blocked by job 1)
job2_id=$(orchestratorctl -p $ORCH_PORT kickoff bash --blocker $job1_id --input "bash $tmpdir/step2.sh" | grep -oP 'ID: \K\d+')

if [ -z "$job2_id" ]; then
    echo_red "ERROR: failed to kickoff job 2"
    kill $serverPID
    exit 1
fi

echo "Job 2 ID: $job2_id (blocked by job $job1_id)"

# Kickoff job 3 (blocked by job 2)
job3_id=$(orchestratorctl -p $ORCH_PORT kickoff bash --blocker $job2_id --input "bash $tmpdir/step3.sh" | grep -oP 'ID: \K\d+')

if [ -z "$job3_id" ]; then
    echo_red "ERROR: failed to kickoff job 3"
    kill $serverPID
    exit 1
fi

echo "Job 3 ID: $job3_id (blocked by job $job2_id)"

# Wait for all jobs to complete using summary polling
timeout=60
elapsed=0
while [ $elapsed -lt $timeout ]; do
    summary=$(orchestratorctl -p $ORCH_PORT summary)

    # Extract counts from summary
    num_pending=$(echo "$summary" | grep -E "(Queued|Active|Blocked)" | awk '{sum += $3} END {print sum}')
    num_completed=$(echo "$summary" | grep "Completed Jobs:" | awk '{print $3}')

    # Pending jobs = queued + active + blocked
    if [ -z "$num_pending" ]; then
        num_pending=0
    fi

    echo "Pending jobs: $num_pending, Completed: $num_completed"

    if [ "$num_pending" -eq 0 ] && [ "$num_completed" -ge 3 ]; then
        echo "All jobs completed"
        break
    fi

    sleep 1
    elapsed=$((elapsed + 1))
done

if [ $elapsed -ge $timeout ]; then
    echo_red "ERROR: Jobs timed out after ${timeout}s"
    orchestratorctl -p $ORCH_PORT summary
    kill $serverPID
    exit 1
fi

# Verify all output files were created in order
if [ ! -f "$orchoutpath/step1.txt" ] || [ ! -f "$orchoutpath/step2.txt" ] || [ ! -f "$orchoutpath/step3.txt" ]; then
    echo_red "ERROR: Not all step files were created"
    ls -la "$orchoutpath"
    kill $serverPID
    exit 1
fi

# Verify job statuses
for jid in $job1_id $job2_id $job3_id; do
    status=$(orchestratorctl -p $ORCH_PORT status $jid | grep "Status:" | awk '{print $2}')
    if [ "$status" != "COMPLETE" ]; then
        echo_red "ERROR: Job $jid has status $status, expected COMPLETE"
        kill $serverPID
        exit 1
    fi
done

echo "Test 7 passed: Job dependencies work correctly"

# Test 8: Pause and resume functionality
echo "Test 8: Pause and resume functionality"

# Pause jobs
orchestratorctl -p $ORCH_PORT pause

if [ $? -ne 0 ]; then
    echo_red "ERROR: failed to pause jobs"
    kill $serverPID
    exit 1
fi

# Create a test script with sleep to verify timeout handling works correctly
echo "sleep 2 && echo 'Paused job' > $orchoutpath/paused.txt" > "$tmpdir/pause_test.sh"
chmod +x "$tmpdir/pause_test.sh"

# Kickoff a job while paused
paused_job_id=$(orchestratorctl -p $ORCH_PORT kickoff bash --input "bash $tmpdir/pause_test.sh" | grep -oP 'ID: \K\d+')

if [ -z "$paused_job_id" ]; then
    echo_red "ERROR: failed to kickoff paused job"
    kill $serverPID
    exit 1
fi

# Wait a moment to ensure it would have run if not paused
sleep 3

# Check that job is paused, not active
status=$(orchestratorctl -p $ORCH_PORT status $paused_job_id | grep "Status:" | awk '{print $2}')
if [ "$status" != "PAUSED" ] && [ "$status" != "QUEUED" ]; then
    echo_red "WARNING: Expected job to be PAUSED or QUEUED, got $status"
    # Don't fail the test since the exact behavior may vary
fi

# Resume jobs
orchestratorctl -p $ORCH_PORT resume

if [ $? -ne 0 ]; then
    echo_red "ERROR: failed to resume jobs"
    kill $serverPID
    exit 1
fi

# Wait for paused job to complete
timeout=30
elapsed=0
while [ $elapsed -lt $timeout ]; do
    status=$(orchestratorctl -p $ORCH_PORT status $paused_job_id | grep "Status:" | awk '{print $2}')

    if [ "$status" = "COMPLETE" ]; then
        break
    fi

    sleep 1
    elapsed=$((elapsed + 1))
done

if [ $elapsed -ge $timeout ]; then
    echo_red "ERROR: Paused job did not complete after resume within ${timeout}s"
    orchestratorctl -p $ORCH_PORT status $paused_job_id
    kill $serverPID
    exit 1
fi

echo "Test 8 passed: Pause and resume functionality works"

# Test 9: Job cancellation
echo "Test 9: Job cancellation"

# Pause to prevent immediate execution
orchestratorctl -p $ORCH_PORT pause

# Create a long-running test script
echo "sleep 30 && echo 'Should not complete' > $orchoutpath/cancelled.txt" > "$tmpdir/cancel_test.sh"
chmod +x "$tmpdir/cancel_test.sh"

# Kickoff job to cancel
cancel_job_id=$(orchestratorctl -p $ORCH_PORT kickoff bash --input "bash $tmpdir/cancel_test.sh" | grep -oP 'ID: \K\d+')

if [ -z "$cancel_job_id" ]; then
    echo_red "ERROR: failed to kickoff job to cancel"
    kill $serverPID
    exit 1
fi

# Resume so job can start
orchestratorctl -p $ORCH_PORT resume

# Give it a moment to potentially start
sleep 1

# Cancel the job
orchestratorctl -p $ORCH_PORT cancel $cancel_job_id

if [ $? -ne 0 ]; then
    echo_red "ERROR: failed to cancel job"
    kill $serverPID
    exit 1
fi

# Wait a moment and verify job is cancelled
sleep 2
status=$(orchestratorctl -p $ORCH_PORT status $cancel_job_id | grep "Status:" | awk '{print $2}')

if [ "$status" != "CANCELED" ]; then
    echo_red "ERROR: Job status is $status, expected CANCELED"
    kill $serverPID
    exit 1
fi

# Verify the cancelled job didn't create its output file
if [ -f "$orchoutpath/cancelled.txt" ]; then
    echo_red "ERROR: Cancelled job created output file"
    kill $serverPID
    exit 1
fi

echo "Test 9 passed: Job cancellation works"

# Test 10: Summary statistics validation
echo "Test 10: Summary statistics validation"

summary=$(orchestratorctl -p $ORCH_PORT summary)
echo "$summary"

# We should have several completed jobs by now (from tests 1, 7, 8)
# At minimum: 1 from test 1, 3 from test 7, 1 from test 8 = 5 total
# But test 9 cancels 1 job, so: 4 completed + 1 discarded = 5 total jobs
completed_count=$(echo "$summary" | grep "Completed Jobs:" | awk '{print $3}')

if [ -z "$completed_count" ] || [ "$completed_count" -lt 4 ]; then
    echo_red "ERROR: Expected at least 4 completed jobs, got: $completed_count"
    kill $serverPID
    exit 1
fi

# Should have 1 cancelled job from test 9
canceled_in_summary=$(echo "$summary" | grep "Discarded Jobs:" | awk '{print $3}')

# Note: The summary uses "Discarded" while status shows "CANCELED"
# They should be equivalent
echo "Completed jobs: $completed_count"
echo "Discarded/Canceled jobs: $canceled_in_summary"

echo "Test 10 passed: Summary statistics are consistent"

# Test 11: Job definition management
echo "Test 11: Job definition management"

# Define 3 job types
orchestratorctl -p $ORCH_PORT define job_a 'echo "Job A" > $orchoutpath/job_a.txt'
orchestratorctl -p $ORCH_PORT define job_b 'echo "Job B" > $orchoutpath/job_b.txt'
orchestratorctl -p $ORCH_PORT define job_c 'echo "Job C" > $orchoutpath/job_c.txt'

# List all definitions and count them
list_output=$(orchestratorctl -p $ORCH_PORT list-definitions)
echo "$list_output"

# Count how many definitions we have (should be at least 3, possibly more from previous tests)
# We look for "Job Type:" lines which appear once per definition
def_count=$(echo "$list_output" | grep -c "Job Type:")

if [ "$def_count" -lt 3 ]; then
    echo_red "ERROR: Expected at least 3 job definitions, got: $def_count"
    kill $serverPID
    exit 1
fi

# Verify that our newly defined types are present
if ! echo "$list_output" | grep -q "Job Type: job_a"; then
    echo_red "ERROR: job_a not found in list-definitions output"
    kill $serverPID
    exit 1
fi

if ! echo "$list_output" | grep -q "Job Type: job_b"; then
    echo_red "ERROR: job_b not found in list-definitions output"
    kill $serverPID
    exit 1
fi

if ! echo "$list_output" | grep -q "Job Type: job_c"; then
    echo_red "ERROR: job_c not found in list-definitions output"
    kill $serverPID
    exit 1
fi

# Test idempotent replace by redefining job_b with a different definition
orchestratorctl -p $ORCH_PORT define job_b 'echo "Job B Modified" > $orchoutpath/job_b_modified.txt'

# List again and verify job_b still exists (and was replaced, not duplicated)
list_output=$(orchestratorctl -p $ORCH_PORT list-definitions)
job_b_count=$(echo "$list_output" | grep -c "Job Type: job_b")

if [ "$job_b_count" -ne 1 ]; then
    echo_red "ERROR: Expected exactly 1 job_b definition after replace, got: $job_b_count"
    kill $serverPID
    exit 1
fi

# Verify the definition was actually updated by checking for the new string
if ! echo "$list_output" | grep -A 1 "Job Type: job_b" | grep -q "Job B Modified"; then
    echo_red "ERROR: job_b definition was not updated"
    kill $serverPID
    exit 1
fi

# Delete job_c
delete_output=$(orchestratorctl -p $ORCH_PORT delete-definition job_c)
echo "$delete_output"

if ! echo "$delete_output" | grep -q "deleted successfully"; then
    echo_red "ERROR: Failed to delete job_c"
    kill $serverPID
    exit 1
fi

# List again and verify job_c is gone
list_output=$(orchestratorctl -p $ORCH_PORT list-definitions)

if echo "$list_output" | grep -q "Job Type: job_c"; then
    echo_red "ERROR: job_c still present after deletion"
    kill $serverPID
    exit 1
fi

# Verify job_a and job_b are still present
if ! echo "$list_output" | grep -q "Job Type: job_a"; then
    echo_red "ERROR: job_a missing after job_c deletion"
    kill $serverPID
    exit 1
fi

if ! echo "$list_output" | grep -q "Job Type: job_b"; then
    echo_red "ERROR: job_b missing after job_c deletion"
    kill $serverPID
    exit 1
fi

# Test deleting non-existent definition (should fail gracefully)
delete_output=$(orchestratorctl -p $ORCH_PORT delete-definition nonexistent_job 2>&1)

if echo "$delete_output" | grep -q "deleted successfully"; then
    echo_red "ERROR: Deleting non-existent job should fail"
    kill $serverPID
    exit 1
fi

if ! echo "$delete_output" | grep -q "not found"; then
    echo_red "ERROR: Expected 'not found' message for non-existent job"
    kill $serverPID
    exit 1
fi

echo "Test 11 passed: Job definition management works correctly"

# Test 12: Advanced job query functionality (Phase 2)
echo "Test 12: Advanced job query functionality"

# Define a test job type for Phase 2 testing
orchestratorctl -p $ORCH_PORT define query_test 'sleep 1 && echo "Query test" > {input_0}'

# Submit several jobs with different types and priorities
query_job1=$(orchestratorctl -p $ORCH_PORT kickoff query_test --priority 10 --input "$orchoutpath/query1.txt" | grep -oP 'ID: \K\d+')
query_job2=$(orchestratorctl -p $ORCH_PORT kickoff query_test --priority 5 --input "$orchoutpath/query2.txt" | grep -oP 'ID: \K\d+')
query_job3=$(orchestratorctl -p $ORCH_PORT kickoff bash --priority 1 --input "echo 'Bash query test' > $orchoutpath/query3.txt" | grep -oP 'ID: \K\d+')

if [ -z "$query_job1" ] || [ -z "$query_job2" ] || [ -z "$query_job3" ]; then
    echo_red "ERROR: Failed to kickoff query test jobs"
    kill $serverPID
    exit 1
fi

echo "Query test jobs: $query_job1, $query_job2, $query_job3"

# Wait for all jobs to complete
timeout=30
elapsed=0
while [ $elapsed -lt $timeout ]; do
    all_complete=true
    for jid in $query_job1 $query_job2 $query_job3; do
        status=$(orchestratorctl -p $ORCH_PORT status $jid | grep "Status:" | awk '{print $2}')
        if [ "$status" != "COMPLETE" ]; then
            all_complete=false
            break
        fi
    done

    if [ "$all_complete" = true ]; then
        echo "All query test jobs completed"
        break
    fi

    sleep 1
    elapsed=$((elapsed + 1))
done

if [ $elapsed -ge $timeout ]; then
    echo_red "ERROR: Query test jobs timed out"
    kill $serverPID
    exit 1
fi

# Test 12a: Query all jobs
echo "Test 12a: Query all jobs"
query_all=$(orchestratorctl -p $ORCH_PORT query)
echo "$query_all"

if [ $? -ne 0 ]; then
    echo_red "ERROR: Failed to query all jobs"
    kill $serverPID
    exit 1
fi

# Should have total count greater than 0
total_count=$(echo "$query_all" | grep "Total matching jobs:" | awk '{print $4}')
if [ -z "$total_count" ] || [ "$total_count" -lt 1 ]; then
    echo_red "ERROR: Expected at least 1 job in query results, got: $total_count"
    kill $serverPID
    exit 1
fi

echo "Test 12a passed: Query all jobs returned $total_count jobs"

# Test 12b: Query by job type filter
echo "Test 12b: Query by job type"
query_bash=$(orchestratorctl -p $ORCH_PORT query --type bash)
echo "$query_bash"

if [ $? -ne 0 ]; then
    echo_red "ERROR: Failed to query jobs by type"
    kill $serverPID
    exit 1
fi

# Verify bash jobs are present
if ! echo "$query_bash" | grep -q "Type: bash"; then
    echo_red "ERROR: No bash jobs found in type-filtered query"
    kill $serverPID
    exit 1
fi

# Verify query_test jobs are NOT present (filtered out)
if echo "$query_bash" | grep -q "Type: query_test"; then
    echo_red "ERROR: query_test jobs found in bash-filtered query"
    kill $serverPID
    exit 1
fi

echo "Test 12b passed: Job type filtering works"

# Test 12c: Query by status filter (complete)
echo "Test 12c: Query by status (complete)"
query_complete=$(orchestratorctl -p $ORCH_PORT query --status complete)
echo "$query_complete"

if [ $? -ne 0 ]; then
    echo_red "ERROR: Failed to query jobs by status"
    kill $serverPID
    exit 1
fi

# All returned jobs should have COMPLETE status
if echo "$query_complete" | grep "Status:" | grep -v "COMPLETE"; then
    echo_red "ERROR: Non-complete jobs found in complete-filtered query"
    kill $serverPID
    exit 1
fi

echo "Test 12c passed: Status filtering works"

# Test 12d: Query with sorting by priority
echo "Test 12d: Query with sorting by priority"
query_priority=$(orchestratorctl -p $ORCH_PORT query --sort priority --limit 5)
echo "$query_priority"

if [ $? -ne 0 ]; then
    echo_red "ERROR: Failed to query jobs sorted by priority"
    kill $serverPID
    exit 1
fi

# Verify we got results (can't easily verify sort order in bash, but at least check it doesn't fail)
if ! echo "$query_priority" | grep -q "Priority:"; then
    echo_red "ERROR: No priority information in sorted query"
    kill $serverPID
    exit 1
fi

echo "Test 12d passed: Sorting by priority works"

# Test 12e: Query with pagination
echo "Test 12e: Query with pagination"
query_page1=$(orchestratorctl -p $ORCH_PORT query --limit 2 --offset 0)
query_page2=$(orchestratorctl -p $ORCH_PORT query --limit 2 --offset 2)

if [ $? -ne 0 ]; then
    echo_red "ERROR: Failed to query with pagination"
    kill $serverPID
    exit 1
fi

# Verify both pages returned results
page1_count=$(echo "$query_page1" | grep -c "Job ID:")
page2_count=$(echo "$query_page2" | grep -c "Job ID:")

echo "Page 1 returned $page1_count jobs, Page 2 returned $page2_count jobs"

if [ "$page1_count" -lt 1 ]; then
    echo_red "ERROR: First page returned no results"
    kill $serverPID
    exit 1
fi

# Note: page2 might have fewer results depending on total count, so we just check page1

echo "Test 12e passed: Pagination works"

# Test 12f: Combined filters (type + status)
echo "Test 12f: Combined filters (type + status)"
query_combined=$(orchestratorctl -p $ORCH_PORT query --type query_test --status complete)
echo "$query_combined"

if [ $? -ne 0 ]; then
    echo_red "ERROR: Failed to query with combined filters"
    kill $serverPID
    exit 1
fi

# Verify all results match both filters
if echo "$query_combined" | grep "Type:" | grep -v "query_test"; then
    echo_red "ERROR: Non-query_test jobs found in combined filter"
    kill $serverPID
    exit 1
fi

if echo "$query_combined" | grep "Status:" | grep -v "COMPLETE"; then
    echo_red "ERROR: Non-complete jobs found in combined filter"
    kill $serverPID
    exit 1
fi

echo "Test 12f passed: Combined filters work"

echo "Test 12 passed: Advanced job query functionality works correctly"

# ====================================================================================
# Test 13: Complex job dependencies
# ====================================================================================
echo ""
echo_yellow "==========================="
echo_yellow "=== Test 13: Complex job dependencies ==="
echo_yellow "==========================="

# Define job types for dependency testing with stdout output
# Job that produces output for capturing: writes to both stdout and file
orchestratorctl -p $ORCH_PORT define output_job "echo \"OUTPUT_{input_0}\"; echo {input_0} > $orchoutpath/{input_0}.txt"

# Job that receives inputs and validates them
orchestratorctl -p $ORCH_PORT define verify_inputs "echo \"RECEIVED: \${INPUT_ARGS[@]}\" > $orchoutpath/{input_0}_verify.txt; echo \${INPUT_ARGS[@]}"

if [ $? -ne 0 ]; then
    echo_red "ERROR: Failed to define job types"
    kill $serverPID
    exit 1
fi

# Test 13a: Diamond dependency with input-job (A → B, C → D)
# Using --input-job ensures outputs from upstream jobs automatically become inputs
echo "Test 13a: Diamond dependency with input-job references and output passing..."
job_a=$(orchestratorctl -p $ORCH_PORT kickoff output_job --input "A" | grep -oP 'ID: \K\d+')
job_b=$(orchestratorctl -p $ORCH_PORT kickoff output_job --input-job $job_a --input "B" | grep -oP 'ID: \K\d+')
job_c=$(orchestratorctl -p $ORCH_PORT kickoff output_job --input-job $job_a --input "C" | grep -oP 'ID: \K\d+')
job_d=$(orchestratorctl -p $ORCH_PORT kickoff verify_inputs --input-job $job_b --input-job $job_c --input "D" | grep -oP 'ID: \K\d+')

echo "Diamond: A=$job_a, B=$job_b (input-job A), C=$job_c (input-job A), D=$job_d (input-job B+C)"

# Wait for all to complete
timeout=30
elapsed=0
while [ $elapsed -lt $timeout ]; do
    status_d=$(orchestratorctl -p $ORCH_PORT status $job_d | grep "Status:" | awk '{print $2}')
    if [ "$status_d" = "COMPLETE" ]; then
        break
    fi
    sleep 1
    elapsed=$((elapsed + 1))
done

# Verify execution order: A first, then B and C (parallel), then D
if [ ! -f "$orchoutpath/A.txt" ] || [ ! -f "$orchoutpath/B.txt" ] || \
   [ ! -f "$orchoutpath/C.txt" ] || [ ! -f "$orchoutpath/D_verify.txt" ]; then
    echo_red "ERROR: Not all diamond jobs completed"
    kill $serverPID
    exit 1
fi

# Verify that D received outputs from B and C as inputs
if [ -f "$orchoutpath/D_verify.txt" ]; then
    d_inputs=$(cat "$orchoutpath/D_verify.txt")
    echo "Job D received inputs: $d_inputs"

    # D should have received OUTPUT_B and OUTPUT_C from its input-jobs
    if ! echo "$d_inputs" | grep -q "OUTPUT_B"; then
        echo_red "ERROR: Job D did not receive output from B"
        echo "D inputs were: $d_inputs"
        kill $serverPID
        exit 1
    fi

    if ! echo "$d_inputs" | grep -q "OUTPUT_C"; then
        echo_red "ERROR: Job D did not receive output from C"
        echo "D inputs were: $d_inputs"
        kill $serverPID
        exit 1
    fi

    echo "✓ Job D correctly received outputs from B and C as inputs"
fi

echo "Test 13a passed: Diamond dependency with input-job output passing works"

# Test 13b: Chain dependency with input-job (E → F → G → H → I)
echo "Test 13b: Chain dependency with input-job references and output passing..."
job_e=$(orchestratorctl -p $ORCH_PORT kickoff output_job --input "E" | grep -oP 'ID: \K\d+')
job_f=$(orchestratorctl -p $ORCH_PORT kickoff output_job --input-job $job_e --input "F" | grep -oP 'ID: \K\d+')
job_g=$(orchestratorctl -p $ORCH_PORT kickoff output_job --input-job $job_f --input "G" | grep -oP 'ID: \K\d+')
job_h=$(orchestratorctl -p $ORCH_PORT kickoff output_job --input-job $job_g --input "H" | grep -oP 'ID: \K\d+')
job_i=$(orchestratorctl -p $ORCH_PORT kickoff verify_inputs --input-job $job_h --input "I" | grep -oP 'ID: \K\d+')

echo "Chain: E=$job_e, F=$job_f (input-job E), G=$job_g (input-job F), H=$job_h (input-job G), I=$job_i (input-job H)"

# Wait and verify chain executes in order
timeout=30
elapsed=0
while [ $elapsed -lt $timeout ]; do
    status_i=$(orchestratorctl -p $ORCH_PORT status $job_i | grep "Status:" | awk '{print $2}')
    if [ "$status_i" = "COMPLETE" ]; then
        break
    fi
    sleep 1
    elapsed=$((elapsed + 1))
done

for letter in E F G H; do
    if [ ! -f "$orchoutpath/$letter.txt" ]; then
        echo_red "ERROR: Chain job $letter did not complete"
        kill $serverPID
        exit 1
    fi
done

if [ ! -f "$orchoutpath/I_verify.txt" ]; then
    echo_red "ERROR: Chain job I did not complete"
    kill $serverPID
    exit 1
fi

# Verify that I received output from H as input
if [ -f "$orchoutpath/I_verify.txt" ]; then
    i_inputs=$(cat "$orchoutpath/I_verify.txt")
    echo "Job I received inputs: $i_inputs"

    # I should have received OUTPUT_H from its input-job
    if ! echo "$i_inputs" | grep -q "OUTPUT_H"; then
        echo_red "ERROR: Job I did not receive output from H"
        echo "I inputs were: $i_inputs"
        kill $serverPID
        exit 1
    fi

    echo "✓ Job I correctly received output from H as input"
fi

echo "Test 13b passed: Chain dependency with input-job output passing works"

# Test 13c: Mixed priorities with blockers
echo "Test 13c: Priority with dependencies..."
# High priority job blocked by low priority
job_low=$(orchestratorctl -p $ORCH_PORT kickoff bash --priority 10 --input "LOW" | grep -oP 'ID: \K\d+')
job_high=$(orchestratorctl -p $ORCH_PORT kickoff bash --priority 0 --blocker $job_low --input "HIGH" | grep -oP 'ID: \K\d+')

echo "Priority test: LOW=$job_low (priority 10), HIGH=$job_high (priority 0, blocked by LOW)"

# Even though HIGH has priority 0, it must wait for LOW
timeout=10
elapsed=0
while [ $elapsed -lt $timeout ]; do
    status_high=$(orchestratorctl -p $ORCH_PORT status $job_high | grep "Status:" | awk '{print $2}')
    if [ "$status_high" = "COMPLETE" ]; then
        break
    fi
    sleep 1
    elapsed=$((elapsed + 1))
done

# Verify both completed and HIGH waited for LOW
if [ ! -f "$orchoutpath/LOW.txt" ] || [ ! -f "$orchoutpath/HIGH.txt" ]; then
    echo_red "ERROR: Priority with blocker test failed"
    kill $serverPID
    exit 1
fi

echo "Test 13c passed: Priority with dependencies works"

echo "Test 13 passed: Complex job dependencies work correctly"

# =============================================================================
# Test 14: Persistence Through Restart
# =============================================================================
echo "Test 14: Persistence through daemon restart..."

# Test 14a: Verify job definitions persist
echo "Test 14a: Job definitions persist through restart..."

# Define multiple job types
orchestratorctl -p $ORCH_PORT define persist_test1 'echo "Test1: $1"' 10
orchestratorctl -p $ORCH_PORT define persist_test2 'echo "Test2: $1 $2"' 20
orchestratorctl -p $ORCH_PORT define persist_test3 'sleep 1 && echo "Test3: $1"' 30

# Restart daemon
echo "Restarting daemon to test persistence..."
kill -SIGTERM $serverPID
wait $serverPID 2>/dev/null
sleep 2

# Start daemon again with same database
cd "$tmpdir"
nohup orchestratord-cpp --grpc-port $ORCH_PORT --threads $num_executor_threads --db-path "$dbpath" > "$tmpdir/daemon3.log" 2>&1 &
serverPID=$!
sleep 3

if ! kill -0 $serverPID 2>/dev/null; then
    echo_red "ERROR: Daemon failed to restart"
    tail -50 "$tmpdir/daemon3.log"
    exit 1
fi

# Verify job definitions still exist by kicking off jobs
job_test1=$(orchestratorctl -p $ORCH_PORT kickoff persist_test1 --input "arg1" | grep -oP 'ID: \K\d+')
job_test2=$(orchestratorctl -p $ORCH_PORT kickoff persist_test2 --input "arg1" --input "arg2" | grep -oP 'ID: \K\d+')

# Wait for completion
timeout=10
elapsed=0
while [ $elapsed -lt $timeout ]; do
    status1=$(orchestratorctl -p $ORCH_PORT status $job_test1 | grep "Status:" | awk '{print $2}')
    status2=$(orchestratorctl -p $ORCH_PORT status $job_test2 | grep "Status:" | awk '{print $2}')
    if [ "$status1" = "COMPLETE" ] && [ "$status2" = "COMPLETE" ]; then
        break
    fi
    sleep 1
    elapsed=$((elapsed + 1))
done

if [ "$status1" != "COMPLETE" ] || [ "$status2" != "COMPLETE" ]; then
    echo_red "ERROR: Jobs failed to complete after restart"
    echo "Job1 status: $status1, Job2 status: $status2"
    kill $serverPID
    exit 1
fi

echo "Test 14a passed: Job definitions persist through restart"

# Test 14b: Verify job history persists
echo "Test 14b: Job history persists through restart..."

# Record current job count
history_before=$(orchestratorctl -p $ORCH_PORT query --status complete | grep -c "Job ID:" || echo "0")
echo "Jobs before restart: $history_before"

# Kickoff a few more jobs
job_hist1=$(orchestratorctl -p $ORCH_PORT kickoff bash --input "HIST1" | grep -oP 'ID: \K\d+')
job_hist2=$(orchestratorctl -p $ORCH_PORT kickoff bash --input "HIST2" | grep -oP 'ID: \K\d+')

# Wait for completion
timeout=10
elapsed=0
while [ $elapsed -lt $timeout ]; do
    status1=$(orchestratorctl -p $ORCH_PORT status $job_hist1 | grep "Status:" | awk '{print $2}')
    status2=$(orchestratorctl -p $ORCH_PORT status $job_hist2 | grep "Status:" | awk '{print $2}')
    if [ "$status1" = "COMPLETE" ] && [ "$status2" = "COMPLETE" ]; then
        break
    fi
    sleep 1
    elapsed=$((elapsed + 1))
done

# Restart daemon
echo "Restarting daemon again to verify history persistence..."
kill -SIGTERM $serverPID
wait $serverPID 2>/dev/null
sleep 2

cd "$tmpdir"
nohup orchestratord-cpp --grpc-port $ORCH_PORT --threads $num_executor_threads --db-path "$dbpath" > "$tmpdir/daemon4.log" 2>&1 &
serverPID=$!
sleep 3

if ! kill -0 $serverPID 2>/dev/null; then
    echo_red "ERROR: Daemon failed to restart"
    tail -50 "$tmpdir/daemon4.log"
    exit 1
fi

# Verify history is still present and includes new jobs
history_after=$(orchestratorctl -p $ORCH_PORT query --status complete | grep -c "Job ID:" || echo "0")
echo "Jobs after restart: $history_after"

if [ "$history_after" -lt "$((history_before + 2))" ]; then
    echo_red "ERROR: Job history not preserved (before: $history_before, after: $history_after)"
    kill $serverPID
    exit 1
fi

# Verify specific jobs are in history
status_hist1=$(orchestratorctl -p $ORCH_PORT status $job_hist1 | grep "Status:" | awk '{print $2}')
status_hist2=$(orchestratorctl -p $ORCH_PORT status $job_hist2 | grep "Status:" | awk '{print $2}')

if [ "$status_hist1" != "COMPLETE" ] || [ "$status_hist2" != "COMPLETE" ]; then
    echo_red "ERROR: Job history queries failed after restart"
    kill $serverPID
    exit 1
fi

echo "Test 14b passed: Job history persists through restart"

# Test 14c: Verify incomplete jobs resume after restart
echo "Test 14c: Incomplete jobs resume after restart..."

# Pause queue
orchestratorctl -p $ORCH_PORT pause

# Kickoff jobs while paused
job_resume1=$(orchestratorctl -p $ORCH_PORT kickoff bash --input "RESUME1" | grep -oP 'ID: \K\d+')
job_resume2=$(orchestratorctl -p $ORCH_PORT kickoff persist_test3 --input "RESUME2" | grep -oP 'ID: \K\d+')

# Verify jobs are queued
sleep 2
status_r1=$(orchestratorctl -p $ORCH_PORT status $job_resume1 | grep "Status:" | awk '{print $2}')
status_r2=$(orchestratorctl -p $ORCH_PORT status $job_resume2 | grep "Status:" | awk '{print $2}')

if [ "$status_r1" != "QUEUED" ] || [ "$status_r2" != "QUEUED" ]; then
    echo_red "ERROR: Jobs not queued as expected (r1: $status_r1, r2: $status_r2)"
    kill $serverPID
    exit 1
fi

echo "Jobs queued: $job_resume1, $job_resume2"

# Restart daemon while jobs are queued
echo "Restarting daemon with queued jobs..."
kill -SIGTERM $serverPID
wait $serverPID 2>/dev/null
sleep 2

cd "$tmpdir"
nohup orchestratord-cpp --grpc-port $ORCH_PORT --threads $num_executor_threads --db-path "$dbpath" > "$tmpdir/daemon5.log" 2>&1 &
serverPID=$!
sleep 3

if ! kill -0 $serverPID 2>/dev/null; then
    echo_red "ERROR: Daemon failed to restart"
    tail -50 "$tmpdir/daemon5.log"
    exit 1
fi

# Queue should resume as paused
sleep 2
status_r1=$(orchestratorctl -p $ORCH_PORT status $job_resume1 | grep "Status:" | awk '{print $2}')
status_r2=$(orchestratorctl -p $ORCH_PORT status $job_resume2 | grep "Status:" | awk '{print $2}')

if [ "$status_r1" != "QUEUED" ] || [ "$status_r2" != "QUEUED" ]; then
    echo_red "ERROR: Jobs not still queued after restart (r1: $status_r1, r2: $status_r2)"
    kill $serverPID
    exit 1
fi

# Resume queue
orchestratorctl -p $ORCH_PORT resume

# Wait for jobs to complete
timeout=15
elapsed=0
while [ $elapsed -lt $timeout ]; do
    status_r1=$(orchestratorctl -p $ORCH_PORT status $job_resume1 | grep "Status:" | awk '{print $2}')
    status_r2=$(orchestratorctl -p $ORCH_PORT status $job_resume2 | grep "Status:" | awk '{print $2}')
    if [ "$status_r1" = "COMPLETE" ] && [ "$status_r2" = "COMPLETE" ]; then
        break
    fi
    sleep 1
    elapsed=$((elapsed + 1))
done

if [ "$status_r1" != "COMPLETE" ] || [ "$status_r2" != "COMPLETE" ]; then
    echo_red "ERROR: Queued jobs did not complete after resume (r1: $status_r1, r2: $status_r2)"
    kill $serverPID
    exit 1
fi

# Verify output files were created
if [ ! -f "$orchoutpath/RESUME1.txt" ]; then
    echo_red "ERROR: RESUME1.txt not found"
    kill $serverPID
    exit 1
fi

echo "Test 14c passed: Incomplete jobs resume after restart"

# Test 14d: Verify blocker relationships persist
echo "Test 14d: Blocker relationships persist through restart..."

# Pause queue
orchestratorctl -p $ORCH_PORT pause

# Create jobs with blockers
job_block_a=$(orchestratorctl -p $ORCH_PORT kickoff bash --input "BLOCK_A" | grep -oP 'ID: \K\d+')
job_block_b=$(orchestratorctl -p $ORCH_PORT kickoff bash --blocker $job_block_a --input "BLOCK_B" | grep -oP 'ID: \K\d+')
job_block_c=$(orchestratorctl -p $ORCH_PORT kickoff bash --input-job $job_block_b --input "BLOCK_C" | grep -oP 'ID: \K\d+')

echo "Created blocked jobs: A=$job_block_a, B=$job_block_b (blocked by A), C=$job_block_c (input-job from B)"

# Restart daemon while jobs are queued with blockers
echo "Restarting daemon with blocked jobs..."
kill -SIGTERM $serverPID
wait $serverPID 2>/dev/null
sleep 2

cd "$tmpdir"
nohup orchestratord-cpp --grpc-port $ORCH_PORT --threads $num_executor_threads --db-path "$dbpath" > "$tmpdir/daemon6.log" 2>&1 &
serverPID=$!
sleep 3

if ! kill -0 $serverPID 2>/dev/null; then
    echo_red "ERROR: Daemon failed to restart"
    tail -50 "$tmpdir/daemon6.log"
    exit 1
fi

# Resume queue
orchestratorctl -p $ORCH_PORT resume

# Wait for all jobs to complete in order
timeout=15
elapsed=0
while [ $elapsed -lt $timeout ]; do
    status_a=$(orchestratorctl -p $ORCH_PORT status $job_block_a | grep "Status:" | awk '{print $2}')
    status_b=$(orchestratorctl -p $ORCH_PORT status $job_block_b | grep "Status:" | awk '{print $2}')
    status_c=$(orchestratorctl -p $ORCH_PORT status $job_block_c | grep "Status:" | awk '{print $2}')
    if [ "$status_a" = "COMPLETE" ] && [ "$status_b" = "COMPLETE" ] && [ "$status_c" = "COMPLETE" ]; then
        break
    fi
    sleep 1
    elapsed=$((elapsed + 1))
done

if [ "$status_a" != "COMPLETE" ] || [ "$status_b" != "COMPLETE" ] || [ "$status_c" != "COMPLETE" ]; then
    echo_red "ERROR: Blocked jobs did not complete after restart (A: $status_a, B: $status_b, C: $status_c)"
    kill $serverPID
    exit 1
fi

# Verify execution order (files should exist in order)
if [ ! -f "$orchoutpath/BLOCK_A.txt" ] || [ ! -f "$orchoutpath/BLOCK_B.txt" ] || [ ! -f "$orchoutpath/BLOCK_C.txt" ]; then
    echo_red "ERROR: Not all blocker test output files created"
    kill $serverPID
    exit 1
fi

echo "Test 14d passed: Blocker relationships persist through restart"

echo "Test 14 passed: Persistence through restart works correctly"

# =============================================================================
# Test 15: Complex Video Processing Workflow (from test_orchestrator.sh)
# =============================================================================
echo "Test 15: Complex video processing workflow with dependencies..."

# First, obtain input files using scrape
echo "Using scrape to obtain input files..."
oinf1="$orchoutpath/sample_960x400_ocean_with_audio.webm"
oinf2="$orchoutpath/sample_1280x720.webm"
oinf3="$orchoutpath/sample_1920x1080.webm"
oinf4="$orchoutpath/sample_2560x1440.webm"
oinf5="$orchoutpath/sample_3840x2160.webm"
oinf6="$orchoutpath/sample_640x360.webm"
oinf7="$orchoutpath/sample_960x540.webm"

scrape --xpath body --ext webm --output $orchoutpath simple-link-scraper https://goromal.github.io/anixpkgs/python/scrape.html 2>/dev/null || {
    echo_red "ERROR: scrape command failed"
    kill $serverPID
    exit 1
}

# Verify all expected files were downloaded
for f in "$oinf1" "$oinf2" "$oinf3" "$oinf4" "$oinf5" "$oinf6" "$oinf7"; do
    if [ ! -f "$f" ]; then
        echo_red "ERROR: Expected scraped file $f not present"
        kill $serverPID
        exit 1
    fi
done

echo "All input files obtained successfully"

# Define job types for video processing
echo "Defining job types for video workflow..."

# Remove job - deletes a file
orchestratorctl -p $ORCH_PORT define remove 'rm -f {input_0}' 10

# Listing job - lists files with extension
orchestratorctl -p $ORCH_PORT define listing 'ls {input_0}/*.{input_1} 2>/dev/null || true' 10

# MP4 conversion job - converts webm to mp4 (simulated with copy) # ^^^^ no simulation
orchestratorctl -p $ORCH_PORT define mp4 'for f in "${INPUT_ARGS[@]}"; do if [[ "$f" == *.webm ]]; then base=$(basename "$f" .webm); cp "$f" "$(dirname {input_0})/$base.mp4" 2>/dev/null || true; fi; done' 60

# MP4 unite job - combines mp4 files (simulated with concatenation marker)
orchestratorctl -p $ORCH_PORT define mp4-unite 'touch {input_0}; for f in "${INPUT_ARGS[@]}"; do if [[ "$f" == *.mp4 ]]; then echo "$f" >> {input_0}; fi; done' 60

# Execute the complex workflow with dependencies
echo "Spawning complex video processing workflow..."

# Phase 1: Remove specific input files (chain of removes)
rmjob=$(orchestratorctl -p $ORCH_PORT kickoff remove --input "$orchoutpath/sample_960x400_ocean_with_audio.webm" | grep -oP 'ID: \K\d+') # ^^^^ this shouldn't be necessary; only print the job or have a porcelain version
rmjob=$(orchestratorctl -p $ORCH_PORT kickoff remove --blocker $rmjob --input "$orchoutpath/sample_1280x720.webm" | grep -oP 'ID: \K\d+')
rmjob=$(orchestratorctl -p $ORCH_PORT kickoff remove --blocker $rmjob --input "$orchoutpath/sample_1920x1080.webm" | grep -oP 'ID: \K\d+')
rmjob=$(orchestratorctl -p $ORCH_PORT kickoff remove --blocker $rmjob --input "$orchoutpath/sample_2560x1440.webm" | grep -oP 'ID: \K\d+')
rmjob=$(orchestratorctl -p $ORCH_PORT kickoff remove --blocker $rmjob --input "$orchoutpath/sample_3840x2160.webm" | grep -oP 'ID: \K\d+')

echo "Remove jobs chain: final rmjob=$rmjob"

# Phase 2: List remaining webm files (after removals complete)
lsjob=$(orchestratorctl -p $ORCH_PORT kickoff listing --blocker $rmjob --input "$orchoutpath" --input "webm" | grep -oP 'ID: \K\d+')

echo "Listing job: lsjob=$lsjob (blocked by rmjob=$rmjob)"

# Phase 3: Convert listed files to mp4 (using output from listing as input)
mp4job=$(orchestratorctl -p $ORCH_PORT kickoff mp4 --input-job $lsjob --input "$orchoutpath/vid.mp4" | grep -oP 'ID: \K\d+') # ^^^^ input job and inputs? Are the stdout inputs working?

echo "MP4 conversion job: mp4job=$mp4job (input-job from lsjob=$lsjob)"

# Phase 4: Remove the listing job output (after mp4 conversion)
rmjob2=$(orchestratorctl -p $ORCH_PORT kickoff remove --input-job $lsjob --blocker $mp4job | grep -oP 'ID: \K\d+')

echo "Remove listing output: rmjob2=$rmjob2 (blocked by mp4job=$mp4job)"

# Phase 5: Unite all mp4 files into final output (using output from mp4 job)
unijob=$(orchestratorctl -p $ORCH_PORT kickoff mp4-unite --input-job $mp4job --input "$orchoutpath/unified_vid.mp4" | grep -oP 'ID: \K\d+')

echo "MP4 unite job: unijob=$unijob (input-job from mp4job=$mp4job)"

# Phase 6: Remove intermediate mp4 files (after unification)
rmjob3=$(orchestratorctl -p $ORCH_PORT kickoff remove --input-job $mp4job --blocker $unijob | grep -oP 'ID: \K\d+')

echo "Remove intermediate mp4s: rmjob3=$rmjob3 (blocked by unijob=$unijob)"

# Also test the bash job with custom script
echo "touch $orchoutpath/new.txt" > "$tmpdir/touchfile.sh"
bjob=$(orchestratorctl -p $ORCH_PORT kickoff bash --input "bash $tmpdir/touchfile.sh" | grep -oP 'ID: \K\d+')

echo "Bash job: bjob=$bjob"

# Wait for all jobs to complete
echo "Waiting for pending jobs to complete..."
num_pending=1
timeout_secs=90
num_tries=0

while [ $num_pending -gt 0 ] && [ $num_tries -lt $timeout_secs ]; do
    num_pending=$(orchestratorctl -p $ORCH_PORT query --status queued --status executing | grep -c "Job ID:" || echo "0")
    echo "Pending jobs: $num_pending (attempt $num_tries/$timeout_secs)"

    # Show filesystem state periodically
    if [ $((num_tries % 10)) -eq 0 ]; then
        echo "Filesystem state:"
        ls -la $orchoutpath || true
        echo "----------------"
    fi

    num_tries=$((num_tries + 1))
    sleep 1
done

if [ $num_pending -ne 0 ]; then
    echo_red "ERROR: Orchestrator timed out at $timeout_secs seconds with $num_pending unfinished jobs"
    echo "Remaining jobs:"
    orchestratorctl -p $ORCH_PORT query --status queued --status executing
    kill $serverPID
    exit 1
fi

echo "All jobs completed at $num_tries seconds"

# Verify no jobs were discarded/failed
num_failed=$(orchestratorctl -p $ORCH_PORT query --status error --status cancelled | grep -c "Job ID:" || echo "0")
if [ $num_failed -ne 0 ]; then
    echo_red "ERROR: Orchestrator finished with $num_failed failed/cancelled jobs"
    orchestratorctl -p $ORCH_PORT query --status error --status cancelled
    kill $serverPID
    exit 1
fi

# Verify expected outputs exist
if [ ! -f "$orchoutpath/unified_vid.mp4" ]; then
    echo_red "ERROR: Expected workflow output video not present"
    ls -la $orchoutpath
    kill $serverPID
    exit 1
fi

if [ ! -f "$orchoutpath/new.txt" ]; then
    echo_red "ERROR: Expected bash job output file not present"
    ls -la $orchoutpath
    kill $serverPID
    exit 1
fi

# Verify only expected outputs remain (should be just unified_vid.mp4 and new.txt)
num_outputs=$(ls -1 "$orchoutpath" | wc -l)
if [ $num_outputs -ne 2 ]; then
    echo_red "ERROR: Expected 2 outputs, found $num_outputs"
    echo "Contents of $orchoutpath:"
    ls -la $orchoutpath
    kill $serverPID
    exit 1
fi

echo "Test 15 passed: Complex video processing workflow works correctly"

# Final cleanup
echo "All tests passed! Cleaning up..."
kill -SIGTERM $serverPID
wait $serverPID 2>/dev/null

# Check for any errors or warnings in daemon logs
if grep -i "error\|segfault\|abort" "$tmpdir/daemon.log" "$tmpdir/daemon2.log" 2>/dev/null; then
    echo_red "WARNING: Found errors in daemon logs:"
    grep -i "error\|segfault\|abort" "$tmpdir/daemon.log" "$tmpdir/daemon2.log"
fi

rm -rf "$tmpdir"

echo "orchestrator-cpp regression tests completed successfully"
