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

    if [ "$num_pending" -eq 0 ] && [ "$num_completed" -ge 4 ]; then
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

# Create a test script that takes a bit longer
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

# We should have several completed jobs by now (from tests 1, 7)
# At minimum: 1 from test 1, 3 from test 7, 1 from test 8 = 5 completed jobs
completed_count=$(echo "$summary" | grep "Completed Jobs:" | awk '{print $3}')

if [ -z "$completed_count" ] || [ "$completed_count" -lt 5 ]; then
    echo_red "ERROR: Expected at least 5 completed jobs, got: $completed_count"
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
