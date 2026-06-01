---
name: mscpp-services
description: Use when building, debugging, reviewing, or extending any C++ service built on the mscpp reactor framework. Covers the three-layer FSM architecture, Store/FSM/Reactor patterns, I/O adapters, port communication, time handling, testing, and common pitfalls discovered during orchestrator-cpp development.
type: skill
---

# mscpp Services Development Guide

Use this skill whenever you are working on a C++ service that uses the **mscpp** reactor framework — implementing new features, reviewing code for compliance, debugging unexpected behavior, or designing a new service architecture.

---

## Framework Overview

**mscpp** enforces a **deterministic, FSM-driven reactor pattern**. Every service built on it must follow a strict three-layer architecture. The framework prevents violations at compile-time through `final` methods and `private` members.

### The Three-Layer Architecture

```
┌─────────────────────────────────────────┐
│  Layer 3: Reactor  (thin wrapper)       │  ← Constructor + optional doPeriodicMaintenance()
├─────────────────────────────────────────┤
│  Layer 2: FSM States (pure functions)   │  ← Port I/O + logic + Store calls, unit-testable
├─────────────────────────────────────────┤
│  Layer 1: Store    (pure functions)     │  ← Business logic, const queries, minimal mutation
└─────────────────────────────────────────┘
```

**The golden rule**: All business logic in a reactor-derived class must live exclusively in FSM state pure functions and Store methods — both must be trivially unit-testable in isolation (i.e., you can pass mock Store structs/methods without spinning up a reactor). The Reactor layer itself contains no logic.

---

## Layer 1: Store (Pure Business Logic)

The Store is a plain struct. Every meaningful decision is a pure function. Mutation is minimal and separate from logic.

```cpp
struct JobQueueStore {
    std::vector<Job> pending_jobs;
    std::map<JobId, JobStatus> job_status;
    int next_job_id{1};

    // ── PURE FUNCTIONS: return results, no side effects ──────────
    struct EnqueueResult {
        bool success;
        JobId job_id;
        std::string error_message;
    };

    EnqueueResult enqueueJob(const JobRequest& request, size_t max_queue_size) const {
        if (request.priority < 0 || request.priority > 100)
            return {false, JobId{0}, "Invalid priority"};
        if (pending_jobs.size() >= max_queue_size)
            return {false, JobId{0}, "Queue full"};
        return {true, JobId{next_job_id}, ""};
    }

    // ── CONST QUERIES: read-only ─────────────────────────────────
    std::optional<Job> getNextJob() const {
        if (pending_jobs.empty()) return std::nullopt;
        return *std::max_element(pending_jobs.begin(), pending_jobs.end(),
            [](const Job& a, const Job& b){ return a.priority < b.priority; });
    }

    bool hasJob(JobId id) const {
        return job_status.find(id) != job_status.end();
    }

    size_t queueSize() const { return pending_jobs.size(); }

    // ── MUTATION: minimal, separate from logic ───────────────────
    void addJob(const Job& job) {
        pending_jobs.push_back(job);
        job_status[job.id] = JobStatus::PENDING;
        next_job_id++;
    }

    void removeJob(JobId id) {
        pending_jobs.erase(
            std::find_if(pending_jobs.begin(), pending_jobs.end(),
                         [id](const Job& j){ return j.id == id; }));
        job_status[id] = JobStatus::COMPLETED;
    }
};
```

**Store rules:**
- No ports, no reactor, no I/O — ever
- Pure functions are `const` methods; mutations are separate non-`const` methods
- Use result structs to return multiple values from pure functions
- Every function is 100% unit-testable in isolation

---

## Layer 2: FSM States (Pure Functions)

FSM states read port inputs, perform logic (including business logic), call Store methods, and write port outputs. Both FSM state `step()` functions and Store methods can contain business logic — the key requirement is that **both must be unit-testable in isolation**, without needing a running reactor. You can pass mock Store structs directly to test state logic.

### State step() Signature

```cpp
size_t step(Store& store,
            Ports& ports,
            const MicroServiceContainer<>& container,
            const LogicalTag& tag,
            const StepTrigger& trigger) override;
```

### StepTrigger Types

```cpp
trigger.type == StepTrigger::Type::HEARTBEAT       // periodic tick (10ms default)
trigger.type == StepTrigger::Type::LOGICAL_ACTION  // event-driven
trigger.action_name                                 // name of the action (when LOGICAL_ACTION)
```

### The Pattern: Check → Read → Call Store → Write → Transition

```cpp
struct ProcessingState : public State<ProcessingState, 1> {
    size_t step(JobQueueStore& store, JobQueuePorts& ports,
                const MicroServiceContainer<>& container,
                const LogicalTag& tag,
                const StepTrigger& trigger) override {

        // ── EVENT-DRIVEN: respond to logical actions ─────────────
        if (trigger.type == StepTrigger::Type::LOGICAL_ACTION) {

            if (trigger.action_name == "on_enqueue_request") {
                if (ports.enqueue_request_in.is_present()) {
                    auto request = ports.enqueue_request_in.get();      // 1. Read
                    auto result = store.enqueueJob(request, 1000);      // 2. Call Store
                    if (result.success) {
                        store.addJob(Job{result.job_id, request.priority, request.payload});
                        ports.enqueue_response_out.set(                 // 3. Write
                            EnqueueResponse{true, result.job_id});
                    } else {
                        ports.error_out.set(result.error_message);
                    }
                }
            }

            if (trigger.action_name == "on_execute_request") {
                if (auto next = store.getNextJob()) {
                    ports.job_out.set(*next);
                    store.removeJob(next->id);
                } else {
                    ports.error_out.set("Queue empty");
                }
            }
        }

        // ── HEARTBEAT: periodic status or timeout checks ─────────
        if (trigger.type == StepTrigger::Type::HEARTBEAT) {
            ports.status_out.set(QueueStatus{store.queueSize(), tag.time});
        }

        // ── STATE TRANSITION: driven by Store queries ────────────
        if (store.queueSize() == 0)
            return IdleState::index();

        return ProcessingState::index();
    }
};
```

### Multi-State FSM

```cpp
// State indices must be 0-based and match StateSet order
struct IdleState      : public State<IdleState,      0> { ... };
struct ProcessingState: public State<ProcessingState, 1> { ... };
struct PausedState    : public State<PausedState,     2> { ... };

using MyStates = StateSet<IdleState, ProcessingState, PausedState>;
```

**FSM State rules:**
- States can contain business logic, but it must be in pure functions that are unit-testable in isolation — pass mock Store structs/methods directly without a reactor
- `step()` methods should be concise (< 50 lines is a good signal; if longer, extract logic into Store or helper functions)
- State transitions return `SomeState::index()`, not raw integers
- Check `port.is_present()` before calling `port.get()`
- **Copy** port data immediately — never hold references across steps

---

## Layer 3: Reactor (Thin Enforcement Shell)

The reactor is mostly a constructor. Do not override `doHeartbeat()` or `executeLogicalAction()` — they are `final` and will fail to compile.

```cpp
class JobQueueReactor : public MicroServiceFSMReactor<
    JobQueueStore,
    JobQueuePorts,
    MicroServiceContainer<>,
    StateSet<IdleState, ProcessingState>
> {
public:
    using Base = MicroServiceFSMReactor<JobQueueStore, JobQueuePorts,
                                        MicroServiceContainer<>,
                                        StateSet<IdleState, ProcessingState>>;

    // Port action map: {"port_name", "logical_action_name"}
    JobQueueReactor(const std::string& name)
        : Base(name, MicroServiceContainer<>{}, {
              {"enqueue_request_in", "on_enqueue_request"},
              {"execute_request_in", "on_execute_request"}
          }) {}

protected:
    // ONLY for logging, metrics, scheduling housekeeping actions — NOT business logic
    void doPeriodicMaintenance(const LogicalTag& tag) override {
        auto time_s = tag.time.count() / 1'000'000'000;
        if (time_s % 60 == 0) {
            SPDLOG_INFO("Queue size: {}", getStore().queueSize());
        }
    }
};
```

**Reactor rules:**
- `doHeartbeat()` and `executeLogicalAction()` are `final` — attempting to override will not compile
- `doPeriodicMaintenance()` is the only valid override; use it only for logging, metrics, and scheduling housekeeping logical actions
- `mStore`, `mPorts`, `mContainer` are `private`; access them via `getStore()` and `getPorts()` (public accessors for testing)
- No business logic anywhere in the reactor class

---

## Port Communication

All communication between reactors must go through ports. No shared state, no direct method calls between reactors.

```cpp
// ✅ Port-based communication between reactors
if (ready_job) {
    ports.job_out.set(*ready_job);   // JobQueue → JobExecutor
}

if (ports.job_in.is_present()) {
    Job job = ports.job_in.get();    // copy immediately
    store.submitJob(job);
}

// ❌ Never do this
executor->submitJob(job);            // direct coupling
```

**Port rules:**
- Always check `is_present()` before `get()`
- Always **copy** the value from `get()` — port data is cleared after each step and a reference will dangle
- Output ports are set at most once per step
- All ports must be registered in `REGISTER_INPUT_PORTS()` (or equivalent)

---

## Critical: Logical Time vs Physical Time

This is the most common source of bugs. They are fundamentally different:

| | Logical Time | Physical Time |
|---|---|---|
| **Source** | Tag-based, advances by heartbeat interval | `std::chrono::steady_clock` |
| **Purpose** | Deterministic event ordering | Real-world wall-clock delays |
| **Use for** | Sequencing reactions, microsteps | Timeouts, rate limiting, scheduling |
| **Type** | `LogicalTag`, `LogicalTime` | `std::chrono::steady_clock::time_point` |

### Physical time for timeouts (REQUIRED)

```cpp
// ✅ CORRECT: physical time for real-world timeout
auto now = std::chrono::steady_clock::now();
auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(
    now - worker.start_time).count();
if (elapsed >= worker.timeout_seconds) {
    killJob(worker.pid);
}

// ❌ WRONG: logical time for timeout — will fire immediately or not at all
Base::schedulePhysicalAction(LogicalTime{300s}, "timeout_action");
```

**The lesson from orchestrator-cpp**: jobs were timing out immediately because logical time had already advanced past 300s at startup. Timeouts, rate limits, and any real-world delay **must** use `std::chrono::steady_clock`.

### Logical time for event sequencing

```cpp
// ✅ Request at Tag(0ms, 0) → response at Tag(0ms, 3) — zero logical latency
// This is correct usage of logical time: ordering within a deterministic execution
if (trigger.type == StepTrigger::Type::LOGICAL_ACTION &&
    trigger.action_name == "on_request") {
    auto response = store.processRequest(ports.request_in.get());
    ports.response_out.set(response);
}
```

---

## I/O Adapter Pattern (Async Frameworks)

When integrating async I/O frameworks (gRPC, ROS2, WebSockets), never put async code inside the reactor. Use the I/O Adapter pattern.

```
┌──────────────────────────────────┐
│  I/O Adapter  (separate thread)  │  ← GrpcAdapter, Ros2Adapter, etc.
│                                  │
│  • Async callbacks               │
│  • scheduleLogicalAction()  ─────┼──→ thread-safe boundary
│  • waitForPortData()        ←────┼──  blocks until reactor responds
└──────────────────────────────────┘
              ↓
┌──────────────────────────────────┐
│  Reactor  (single-threaded)      │  ← deterministic, FSM-driven
└──────────────────────────────────┘
```

```cpp
// main.cpp — wiring up the layers
auto reactor = std::make_shared<MyServiceReactor>("service", port_actions);

GrpcAdapter<MyServiceReactor> grpc_adapter(reactor.get(), "0.0.0.0:50051");
grpc_adapter.start();   // spawns gRPC thread

ReactorScheduler scheduler;
reactor->setScheduler(&scheduler);
scheduler.registerReactor(reactor);
scheduler.run();        // deterministic single-threaded loop

grpc_adapter.stop();
```

**I/O Adapter rules:**
- Async I/O runs in a separate thread — never in the reactor
- Use `scheduleLogicalAction()` to push events into the reactor (thread-safe)
- Use `waitForPortData()` to receive responses from the reactor (blocks the adapter thread, not the reactor)
- The reactor itself remains single-threaded and never needs locks for business logic

---

## Non-Blocking Operations

The reactor runs on a single thread. Any blocking call freezes the entire system.

```cpp
// ✅ Non-blocking process poll
int status;
pid_t result = waitpid(worker.pid, &status, WNOHANG);
if (result == worker.pid) {
    // completed
} else if (result == 0) {
    // still running — will check on next heartbeat
}

// ❌ Blocks reactor indefinitely
waitpid(worker.pid, &status, 0);
```

**Never block the reactor.** Use `WNOHANG`, polling via heartbeat, async operations, or background threads with I/O adapters.

---

## Testing Patterns

### Unit test Store functions directly

```cpp
TEST_CASE("JobQueueStore: enqueueJob validation", "[Store][Unit]") {
    JobQueueStore store;

    SECTION("Valid job accepted") {
        auto result = store.enqueueJob({.priority = 50, .payload = "data"}, 1000);
        REQUIRE(result.success);
        REQUIRE(result.job_id.value == 1);
    }

    SECTION("Invalid priority rejected") {
        auto result = store.enqueueJob({.priority = -5, .payload = "data"}, 1000);
        REQUIRE_FALSE(result.success);
        REQUIRE(result.error_message == "Invalid priority");
    }
}
```

### Integration test Reactor behavior via public accessors

```cpp
TEST_CASE("JobQueueReactor: enqueue flow", "[Reactor][Integration]") {
    JobQueueReactor reactor("test_queue");
    LogicalTag tag{LogicalTime{1000000000}};

    SECTION("Enqueue via logical action") {
        reactor.getPorts().enqueue_request_in.set({.priority = 75, .payload = "test"});
        reactor.executeLogicalAction(tag, "on_enqueue_request");

        REQUIRE(reactor.getStore().queueSize() == 1);
        REQUIRE(reactor.getPorts().enqueue_response_out.is_present());
        REQUIRE(reactor.getPorts().enqueue_response_out.get().success);
    }
}
```

**Testing rules:**
- Unit test all Store pure functions in isolation — they have no dependencies
- Integration test Reactor behavior using `getStore()` and `getPorts()` public accessors
- Test state transitions, error paths, and heartbeat behavior separately

---

## Anti-Patterns (Do Not Do These)

### Untestable logic baked into step() inline

```cpp
// ❌ Logic is not unit-testable in isolation — it's fused with port I/O
size_t step(...) {
    if (request.amount < 0) { ports.error_out.set("Invalid"); return ...; }
    if (store.balance < request.amount) { ports.error_out.set("Insufficient"); return ...; }
    store.balance -= request.amount;  // direct mutation mixed with logic
    ...
}

// ✅ Extract logic into a pure function on Store (or a free function) — then it's testable
// in isolation via mock Store, without a reactor
size_t step(...) {
    auto result = store.withdraw(request.amount);  // pure, easily unit-tested
    if (result.success) {
        store.updateBalance(result.new_balance);
        ports.success_out.set(true);
    } else {
        ports.error_out.set(result.error_message);
    }
}
```

### Overriding doHeartbeat() or executeLogicalAction()

```cpp
// ❌ Will not compile — these are final
void doHeartbeat(const LogicalTag& tag) override { ... }
void executeLogicalAction(const LogicalTag& tag, const std::string& action) override { ... }

// ✅ Use doPeriodicMaintenance() for housekeeping only
void doPeriodicMaintenance(const LogicalTag& tag) override {
    SPDLOG_INFO("Status: {}", getStore().queueSize());
}
```

### Mixing async I/O into the reactor

```cpp
// ❌ Race conditions, non-deterministic
class BadReactor : public MicroServiceFSMReactor<...> {
    grpc::ServerCompletionQueue* cq_;  // async I/O in reactor
    std::thread grpc_thread_;
};

// ✅ Use IOAdapter in a separate thread, bridge via scheduleLogicalAction
```

### Using logical time for real-world timeouts

```cpp
// ❌ Will fire immediately or never, depending on current logical time
Base::schedulePhysicalAction(LogicalTime{300s}, "timeout");

// ✅ Track wall-clock time in Store
auto now = std::chrono::steady_clock::now();
if (now - worker.start_time >= std::chrono::seconds(300)) { ... }
```

### Holding references to port data across steps

```cpp
// ❌ Dangling reference — port cleared after step
const Job& job = ports.job_in.get();
// ... later in same or different step: UB

// ✅ Copy immediately
Job job = ports.job_in.get();
```

---

## Design Compliance Checklist

Before committing changes, verify:

**Reactor Design**
- [ ] All inter-reactor communication is port-based (no shared state, no direct calls)
- [ ] All business logic lives in FSM state pure functions or Store methods (not in the Reactor class itself)
- [ ] Both FSM state functions and Store methods are unit-testable in isolation (mock Store structs work without a reactor)
- [ ] `doPeriodicMaintenance()` only does housekeeping (logging, metrics, scheduling actions)
- [ ] Physical time (`std::chrono::steady_clock`) used for real-world delays and timeouts
- [ ] Logical time used for event ordering only

**Port Usage**
- [ ] All input ports registered
- [ ] Port data is copied, not referenced
- [ ] Output ports set at most once per step
- [ ] `is_present()` checked before `get()`

**State Machines**
- [ ] State transitions return the correct state index
- [ ] States are cohesive and concise (< 50 lines is a good signal)
- [ ] Business logic extracted to Store methods

**Testing**
- [ ] Store pure functions have unit tests
- [ ] Reactor behavior has integration tests
- [ ] Error paths are tested

**Code Quality**
- [ ] Debug `fprintf`/`printf` removed or guarded by `SPDLOG_DEBUG`
- [ ] No blocking operations in reactor (no `waitpid` without `WNOHANG`, no `sleep`, no synchronous network calls)

---

## orchestrator-cpp Architecture Reference

The orchestrator-cpp service is a canonical example of the mscpp three-layer pattern, with four reactors wired in sequence:

```
JobServer (gRPC adapter + routing)
    │ ports: define_job_out, kickoff_job_out
    ↓
JobQueue (job state management, dependency resolution, priority ordering)
    │ ports: job_out
    ↓
JobExecutor (fork/exec bash scripts, non-blocking poll, physical-time timeouts)
    │ ports: job_result_out, job_history_out
    ↓
JobDatabase (SQLite persistence, idempotent writes via INSERT OR REPLACE)
```

Key lessons from its implementation:
1. **Timeout bug**: Originally used logical time for job timeouts — all jobs timed out immediately. Fix: physical time via `std::chrono::steady_clock`.
2. **Non-blocking execution**: `waitpid(..., WNOHANG)` polled on heartbeat; blocking `waitpid` would freeze the reactor.
3. **Idempotent persistence**: SQLite writes use `INSERT OR REPLACE` to handle retries and restarts.
4. **gRPC adapter**: JobServer is an I/O adapter pattern — gRPC runs in a separate thread, bridges to reactor via logical actions.
