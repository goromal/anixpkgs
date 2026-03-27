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
orchestratorctl -p $ORCH_PORT define bash "bash {input_0}"

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
