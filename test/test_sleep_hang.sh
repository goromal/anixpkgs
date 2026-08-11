#!/bin/bash
# Minimal test to reproduce the sleep hang issue

tmpdir="/tmp/test_sleep_hang_$$"
mkdir -p "$tmpdir"
cd "$tmpdir"

echo "Test 1: Direct execution of sleep script (baseline)"
echo "sleep 1 && echo 'done'" > test1.sh
chmod +x test1.sh
timeout 5 bash test1.sh && echo "✓ Test 1 PASSED" || echo "✗ Test 1 FAILED (timeout)"

echo ""
echo "Test 2: Fork/exec pattern (mimics orchestrator)"
cat > test2.cpp << 'EOF'
#include <unistd.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <cstdio>
#include <cstring>

int main() {
    const char* script = "sleep 1 && echo 'done'";

    pid_t pid = fork();
    if (pid == 0) {
        // Child: redirect stdin
        int devnull = open("/dev/null", O_RDONLY);
        if (devnull >= 0) {
            dup2(devnull, STDIN_FILENO);
            close(devnull);
        }

        execlp("/bin/sh", "sh", "-c", script, (char*)nullptr);
        _exit(127);
    }

    // Parent: wait with timeout
    int timeout = 5;
    int elapsed = 0;
    while (elapsed < timeout) {
        int status;
        pid_t result = waitpid(pid, &status, WNOHANG);
        if (result > 0) {
            printf("Child completed: exit=%d\n", WEXITSTATUS(status));
            return 0;
        }
        sleep(1);
        elapsed++;
    }

    printf("TIMEOUT: Child still running after %ds\n", timeout);
    kill(pid, SIGKILL);
    return 1;
}
EOF

g++ -o test2 test2.cpp
timeout 10 ./test2 && echo "✓ Test 2 PASSED" || echo "✗ Test 2 FAILED (timeout)"

echo ""
echo "Test 3: Fork/exec with setsid() (create new session)"
cat > test3.cpp << 'EOF'
#include <unistd.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <cstdio>

int main() {
    const char* script = "sleep 1 && echo 'done'";

    pid_t pid = fork();
    if (pid == 0) {
        setsid();  // Create new session

        int devnull = open("/dev/null", O_RDONLY);
        if (devnull >= 0) {
            dup2(devnull, STDIN_FILENO);
            close(devnull);
        }

        execlp("/bin/sh", "sh", "-c", script, (char*)nullptr);
        _exit(127);
    }

    int timeout = 5;
    int elapsed = 0;
    while (elapsed < timeout) {
        int status;
        pid_t result = waitpid(pid, &status, WNOHANG);
        if (result > 0) {
            printf("Child completed: exit=%d\n", WEXITSTATUS(status));
            return 0;
        }
        sleep(1);
        elapsed++;
    }

    printf("TIMEOUT: Child still running after %ds\n", timeout);
    kill(pid, SIGKILL);
    return 1;
}
EOF

g++ -o test3 test3.cpp
timeout 10 ./test3 && echo "✓ Test 3 PASSED" || echo "✗ Test 3 FAILED (timeout)"

echo ""
echo "Test 4: Check for zombie processes or lingering children"
ps aux | grep -E "(sleep|test[0-9])" | grep -v grep

cd /tmp
rm -rf "$tmpdir"
echo ""
echo "Investigation complete"
