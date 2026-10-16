---
name: msrs-services
description: Use when designing, building, reviewing, or debugging any Rust service built on the msrs framework (copper-rs + statig successor to mscpp). Covers robot-service contracts with draw.io or Excalidraw drawings, the Store/FsmSpec/FsmTask architecture, and deterministic bring-up. Read the linked template when specifying behavior and the tutorial for small worked examples.
---

# msrs Services Development Guide

Use this skill whenever you are working on a Rust service that uses the **msrs** framework ([goromal/msrs](https://github.com/goromal/msrs)) — designing a new service from an FSM diagram, implementing it, reviewing code for compliance, or debugging behavior.

**Ground-truth note:** compiler-verified cu29/statig signatures live in the msrs repo at `docs/superpowers/notes/copper-statig-signatures.md`. That file is updated alongside the code and **wins over this skill on any conflict**. Consult it before fighting the compiler on trait shapes, payload bounds, or RON parsing.

---

## Framework Overview

**msrs** packages deterministic, FSM-driven microservices on top of [copper-rs](https://github.com/copper-project/copper-rs) (`cu29`, a data-oriented deterministic robotics runtime) and [statig](https://github.com/mdeloof/statig) (hierarchical state machines). Every service follows the same layering:

```
┌───────────────────────────────────────────────┐
│  Transport (own driver thread, RtConfig)      │  ← middleware I/O only (gRPC/zenoh/etc.)
├────────────────── channels ───────────────────┤
│  IngressTask → FsmTask → EgressTask           │  ← copper-rs DAG, deterministic, logged
│                  │                            │
│         statig FSM (handlers)                 │  ← dispatch + transitions
│                  │                            │
│         Store (pure business logic)           │  ← unit-testable in isolation
└───────────────────────────────────────────────┘
```

**The golden rule:** business logic lives exclusively in pure `Store` methods and statig state handlers, reachable through the copper-agnostic `FsmSpec::step` seam. Everything above that seam must be testable with `msrs_core::run_step` — no copper runtime, no threads, no I/O.

**The determinism rule:** handlers must not read wall-clock time, environment, or randomness. Supply time and every other decision input explicitly and record them. Replay the same ordered triggers from the same initial state/configuration and compare outputs. Replay proves reproducibility for the exercised trace; requirements, timing, and failure tests establish whether that behavior is correct.

---

## Design First: Service Contract + Editable Drawings

Every new service starts from a `SPEC.md`, written or approved by the human before implementation. Read [the service-spec template](references/service-spec-template.md) when designing or reviewing a service. For a first walkthrough, read [the tutorial](references/spec-tutorial.md); it progresses from a two-state indicator to hierarchy and then time-dependent behavior.

Use **draw.io (`.drawio`) or Excalidraw (`.excalidraw`)** for authored drawings, with an adjacent SVG preview. Preserve the user's chosen editor; do not replace their drawing with Mermaid. Keep editable sources and previews under version control. These text/vector design assets belong with the service spec.

The drawing and its associated contracts together form the spec. Use stable state, transition, interface, and requirement IDs to connect drawings, tables, code, and tests. A drawing need not contain every field or timing rule: refer to its contract by ID. Neither prose nor drawing silently overrides the other; resolve disagreements before implementing the affected behavior.

Choose views by what needs explanation:

- **Context/topology:** service boundaries, peers, authority, hardware, deployment and message paths. One sentence can suffice for a trivial isolated example.
- **Behavior:** states, containment, transitions, guards and effects. Distinguish command acceptance from observed physical completion.
- **Sequence/timing:** handoffs, acknowledgements, deadlines, races and failures across components when ordering matters.

Keep small specs small: combine sections or mark them not applicable with a reason. For production services, settle authority, interface semantics, event ordering, timing, failure/restart behavior, and acceptance scenarios before coding those behaviors. Record unanswered decisions with an owner and whether they block implementation; agents must not invent missing behavioral requirements.

### Contract → code traceability

| Spec element | Implementation and verification |
|--------------|---------------------------------|
| State ID and meaning | Named leaf handler, or an explicit mapping if code names differ; state invariant assertions |
| Transition ID | Source, event, guard, target, effects and rejection behavior mapped to handler(s) and scenario tests |
| Guard | Pure query with defined conditions/units, not just an unexplained method name |
| Initial state | Explicit initial leaf and initialized store/configuration; startup effects specified |
| Composite boundary | statig superstate for genuine containment; children explicitly defer shared events |
| Entry into a composite | Explicit target leaf, e.g. `Transition(State::idle())`; the drawing's initial arrow does not generate this behavior |
| Shared boundary transition | Test every descendant leaf, including precedence, effects and forbidden outputs |
| Entry/exit/internal actions | Named effects, their order, and whether an internal event re-enters the state |
| Concurrent modes or service interactions | Explicit coordination, ownership and ordering contract; do not assume a composite supplies concurrency |
| Requirement ID | Acceptance scenario(s), including negative, boundary and failure cases where relevant |

Update the contract, editable drawing and preview in the same PR as behavior changes. Keep implementation refinements traceable; do not force high-level architecture into a one-node/one-Rust-handler representation.

---

## Layer 1: Store (Pure Business Logic)

A plain struct implementing the `msrs_core::Store` marker trait. Queries take `&self`, mutations take `&mut self` and stay minimal. No ports, no transport, no clock, no I/O — ever.

```rust
use msrs_core::store::Store;

#[derive(Default)]
pub struct EchoStore {
    pub count: u64,
}

impl Store for EchoStore {}

impl EchoStore {
    /// Pure query: does not mutate; caller applies the mutation separately.
    pub fn echo(&self, msg: &str) -> String {
        format!("echo {}: {}", self.count + 1, msg)
    }
}
```

**Store rules:**
- Pure queries (`&self`) compute decisions; mutations (`&mut self`) apply them — keep the two separate
- Return result structs from queries when there are multiple outputs
- Every method is unit-testable with a bare `Store::default()`

---

## Layer 2: statig Machine + FsmSpec

The statig machine dispatches events into handlers; handlers call the store and record outputs on a context struct. An `FsmSpec` impl bridges the machine to msrs.

### statig 0.4 signatures that actually compile

```rust
use statig::blocking::InitializedStateMachine;
use statig::prelude::*;

#[derive(Default)]
pub struct EchoCtx {
    pub store: EchoStore,
    pub emitted: Option<String>,   // drained by FsmSpec::step after dispatch
}

pub struct EchoEvent(pub String);

#[derive(Default)]
pub struct EchoGate;

#[state_machine(initial = "State::running()", state(derive(Debug)))]
impl EchoGate {
    #[state]
    fn running(context: &mut EchoCtx, event: &EchoEvent) -> Outcome<State> {
        context.emitted = Some(context.store.echo(&event.0));
        context.store.count += 1;
        Handled            // or Transition(State::other())
    }
}
```

Critical details (all compiler-enforced, all in the msrs notes file):
- Context is injected **by parameter name**: the parameter must be called `context`
- `InitializedStateMachine` is **not `Default`** (init needs the context) — hold it in an `Option` and lazily initialize on first step:

```rust
let sm = EchoGate::default()
    .uninitialized_state_machine()
    .init_with_context(&mut self.ctx);
// dispatch:
sm.handle_with_context(&EchoEvent(msg.clone()), &mut self.ctx);
```

### Hierarchical modes and event precedence

Use superstates for genuine containment and shared behavior: `enabled` can contain `idle` and `active`, with a common `disable` transition. Separate mode dimensions (such as authority, mission phase and health) may coexist; specify their legal combinations and arbitration instead of forcing them into a tree. Separate tasks/services are appropriate for distinct processing or ownership boundaries, with explicit message and timing contracts.

Statig dispatches **child first**. A superstate sees an event only if the child returns `Super`; hierarchy alone supplies no priority or preemption. For shared events such as disable, specify that every descendant defers them without producing conflicting effects, and test that rule. Define priority between distinct events at the deterministic dispatch seam as well: a parent handler cannot reorder an input queue. A software e-stop event also needs a defined physical outcome, latency and fault/reset contract; naming a state `disabled` does not establish those properties.

For a composite `enabled` with initial child `idle`, explicitly implement entry as `Transition(State::idle())`. Do not transition to a generated `State::enabled()` unless `enabled` is actually a leaf. State whether re-entry resets to `idle` or restores history; history needs explicit implementation. Keep shared events flowing upward with `Super` through intermediate superstates; `Handled` stops propagation.

The current `FsmTask` adapter has one input and one output payload slot. That is an adapter constraint, not a restriction on conceptual service boundaries or Copper's general capabilities. Composite inputs, output batches, or a different adapter may be required. Derive latency from the actual schedule and queueing behavior; do not assume each additional task adds one tick.

See [statig's dispatch and transition semantics](https://docs.rs/statig/0.4.1/statig/#implementation). Consult the msrs compiler-verified notes for signatures; its existing flat-machine example does not by itself verify every hierarchical pattern.

### FsmSpec: the copper-agnostic seam

```rust
use msrs_core::{Effects, FsmSpec, Trigger};

impl FsmSpec for EchoMachine {
    type In = EchoMsg;
    type Out = EchoMsg;

    fn step(&mut self, trigger: &Trigger<'_, EchoMsg>, effects: &mut Effects<EchoMsg>) {
        if let Some(msg) = trigger.message() {
            // dispatch into the statig machine, then drain ctx.emitted
            // and effects.emit(...) the result
        }
        // Trigger::Tick(nanos) → time-dependent work using ONLY supplied time
    }
}
```

### Check adapter capabilities before promising behavior

The following constraints were checked against msrs `9528ecf69523e0fde0ff38b2f72441197cf29729`. Re-check the service's pinned revision before choosing an implementation; record any capability gap in its spec rather than weakening its requirements.

- **Tick starvation:** [`FsmTask::process`](https://github.com/goromal/msrs/blob/9528ecf69523e0fde0ff38b2f72441197cf29729/crates/msrs-core/src/fsm_task.rs) chooses `Message` when input is present, otherwise `Tick(ctx.now())`. Tick is not guaranteed periodic under traffic. Watchdogs and deadlines need a bounded, recorded time/dispatch mechanism that still runs under sustained input.
- **One effect payload:** [`Effects::take_one`](https://github.com/goromal/msrs/blob/9528ecf69523e0fde0ff38b2f72441197cf29729/crates/msrs-core/src/effects.rs), used by `run_step`, returns the first emission and discards additional ones. Emit one composite output if a step requires several effects, or change the adapter; do not call `emit` repeatedly and expect later delivery. Specify how a batch is applied and how partial application is handled.
- **Ingress and overload:** [`IngressTask`](https://github.com/goromal/msrs/blob/9528ecf69523e0fde0ff38b2f72441197cf29729/crates/msrs-transport/src/tasks.rs) consumes at most one queued message per iteration. Define queue bounds, ordering and overflow behavior, and preserve acquisition time separately from ingress time when freshness matters.
- **Restart/replay:** the adapter has a no-op `Freezable` implementation. Do not promise restored machine/store state without implementing it; define cold-start state and what replay requires.

Timeouts and rate limits compare explicit monotonic timestamps supplied to the pure seam. Define clock domain, units, ordering and reset behavior. **Never** read `SystemTime::now()` / `Instant::now()` inside handlers. Application-level timestamped inputs can supply time too, provided their production, scheduling and recording satisfy the service contract.

---

## Layer 3: Copper Wiring

`msrs_core::FsmTask<M>` adapts any `M: FsmSpec + Default + Send + Sync + 'static` (with `M::In/Out: CuMsgPayload`) into a copper transform task. The service binary supplies the app struct and RON config.

### Payload rules (the #1 compile-error source)

Copper payloads must implement `TypePath`; under cu29 rc2's default (reflect-off) build only primitives do, so **`String` (or any std collection) cannot be a payload directly**. Wrap it in a newtype with the full derive set:

```rust
use bincode::{Decode, Encode};
use cu29::prelude::Reflect;
use serde::{Deserialize, Serialize};

#[derive(Default, Debug, Clone, PartialEq, Encode, Decode, Serialize, Deserialize, Reflect)]
pub struct EchoMsg(pub String);
```

### Boilerplate that must exist

```rust
// build.rs — REQUIRED or #[copper_runtime] fails to expand
fn main() {
    println!("cargo:rustc-env=LOG_INDEX_DIR={}", std::env::var("OUT_DIR").unwrap());
}
```

```rust
// main.rs
pub type EchoIngress = IngressTask<EchoMsg>;          // crate-root aliases: RON's
pub type EchoFsm = msrs_core::FsmTask<EchoMachine>;   // type: field cannot parse
pub type EchoEgress = EgressTask<EchoMsg>;            // generic paths

#[copper_runtime(config = "copperconfig.ron")]
struct EchoApplication {}

gen_cumsgs!("copperconfig.ron");   // needed to read the unified log back
```

```ron
// copperconfig.ron — msg: must be FULLY qualified ("crate::...") because
// gen_cumsgs! emits into a nested module
(
    tasks: [
        ( id: "ingress", type: "EchoIngress" ),
        ( id: "echo",    type: "EchoFsm" ),
        ( id: "egress",  type: "EchoEgress" ),
    ],
    cnx: [
        ( src: "ingress", dst: "echo",   msg: "crate::EchoMsg" ),
        ( src: "echo",    dst: "egress", msg: "crate::EchoMsg" ),
    ],
)
```

Manual stepping (the deterministic loop): `start_all_tasks()` → `run_one_iteration()` × N → `stop_all_tasks()`, then **`drop(application)`** to flush the unified log before reading it.

---

## Transport Integration

The `Transport` trait is the only place middleware lives. It runs on its own driver thread and speaks to the DAG through crossbeam channels — it never touches copper internals.

```rust
pub trait Transport: Send + 'static {
    type Inbound: Send + 'static;    // middleware → DAG
    type Outbound: Send + 'static;   // DAG → middleware
    fn run(self, rx_out: Receiver<Self::Outbound>, tx_in: Sender<Self::Inbound>)
        -> Result<(), String>;
}
```

Wiring order matters — channels are installed into a process-global registry that the copper tasks' `new()` consumes:

```rust
let handles = TransportDriver::spawn(transport, RtConfig::normal()); // or Fifo(prio) + pinning
IngressTask::<EchoMsg>::install(handles.from_transport);   // BEFORE the app is built
EgressTask::<EchoMsg>::install(handles.to_transport);
let mut app = EchoApplication::builder()...build()?;
```

- `install()` **panics on double-install** and `new()` **consumes** the slot — building a second app (e.g. for replay) requires a fresh `install()` first
- Shutdown is channel disconnect: drop the app, then `handles.join.join()`
- Transport-level faults should enter the DAG as `TransportEvent::Error(String)` payload variants, not be swallowed on the driver thread

---

## Testing & the Bring-Up Gate

### Unit: transitions, invariants and scenarios

`msrs_core::run_step` drives one FSM step with no runtime:

```rust
#[test]
fn idle_activates_on_foo_cmd() {
    let mut m = MyMachine::default();
    let cmd = FooCmd::new(...);
    assert_eq!(run_step(&mut m, &Trigger::Message(&cmd)), Some(expected_output));
    assert_eq!(m.state_name(), "Active");   // expose a Debug view of sm.state()
}

#[test]
fn tick_emits_nothing_when_idle() {
    let mut m = MyMachine::default();
    assert_eq!(run_step(&mut m, &Trigger::Tick(123)), None);
}
```

Cover every specified transition, guard rejection, internal action, and time boundary. Test shared events from every descendant state, competing-event order, required and forbidden effects, and invariants across multi-step scenarios. Test store queries directly. Edge coverage alone does not demonstrate lifecycle, timing, or physical behavior; add transport/simulation/hardware evidence appropriate to the contract.

### The replay-determinism gate (required before declaring bring-up done)

1. **Capture the complete decision trace:** drive acceptance scenarios through the service's real transport and record initial state/configuration and versions, every ordered trigger (including exact tick timestamps, faults, resets and empty cycles if meaningful), and outputs. Record any arbitration result that depends on external arrival order. Verify that the log actually contains the inputs needed to replay the pure seam; task payloads alone may omit time.
2. **Read back:** decode the recorded copperlists (`gen_cumsgs!` + `UnifiedLoggerBuilder` read mode + `decode_from_std_read::<CopperList<CuMsgs>, _, _>`). Under the documented cu29 rc2 configuration, do **not** depend on `cu29-export`: its reflect feature conflicts with the transport tasks.
3. **Replay:** initialize the same state/configuration and invoke `run_step` with the exact recorded trigger sequence. Never substitute replay-machine wall time. Restore a checkpoint only if complete state restoration is implemented; otherwise replay from startup.
4. **Diff:** compare the specified serialized effect payloads, ordering and absence of output per step. Require bit-identical results for that representation. Diagnose missing trace data, wrong initialization, implementation/version drift and nondeterminism before changing the check. Define separately any timing metadata produced outside the pure seam.
5. **Check requirements:** run scenario assertions and deadline measurements as well. Reproducing an incorrect trace does not make the service correct.

The msrs `examples/echo` binary demonstrates message-only replay. Its reader skips empty ingress cycles and its replay never supplies ticks. Use it as scaffolding, not as evidence that a timed service's replay gate is complete.

---

## Anti-Patterns

- **I/O or clock reads inside Store or handlers** — breaks the replay gate. Time is an explicit recorded input; I/O lives in the Transport.
- **`String`/`Vec<T>` as a copper payload** — no `TypePath` under reflect-off; use a derive-complete newtype.
- **Depending on `cu29-export`** — force-enables bevy_reflect and breaks the transport tasks; inline the log reader instead.
- **Generic paths in RON `type:`** — the codegen can't parse them; use crate-root type aliases.
- **Unqualified `msg:` in RON** — must be `"crate::MyMsg"`.
- **Reusing installed channels for a second app build** — `new()` consumed them; `install()` again.
- **Blocking in `FsmSpec::step`** — the DAG iteration stalls; anything slow belongs on the transport thread.
- **Logic in the binary crate** — `main.rs` is wiring only (aliases, app struct, transport spawn, run loop); if `main.rs` contains a decision, it can't be replayed or unit-tested.

---

## Compliance Checklist

**Spec**
- [ ] SPEC.md and editable draw.io/Excalidraw drawings with previews agree; IDs trace behavior to code/tests
- [ ] Authority, interfaces, event priority, effects, timing and failure/restart behavior are settled or explicitly not applicable
- [ ] Applicable views and acceptance scenarios exist; blocking design decisions and adapter gaps are resolved before dependent implementation
- [ ] Contract, drawing and preview updated in the same PR as any behavior change

**Architecture**
- [ ] All business logic in Store methods + statig handlers (reachable via `run_step`)
- [ ] Store has no I/O, no clock, no runtime dependencies
- [ ] Payloads are derive-complete newtypes
- [ ] `main.rs` is wiring only

**Determinism**
- [ ] No wall-clock/random/env reads inside the `FsmSpec` seam; complete ordered triggers and initial state/configuration are recorded
- [ ] Replay-determinism gate implemented and passing (bit-identical diff)

**Testing**
- [ ] Transition and invariant tests include shared-event precedence, rejection, time boundaries and required/forbidden effects
- [ ] Scenario, fault/restart and load/deadline checks satisfy the service contract
- [ ] Store queries unit-tested directly

**Wiring**
- [ ] `build.rs` exports `LOG_INDEX_DIR`
- [ ] `install()` before app build; fresh installs before any second build
- [ ] Transport errors surfaced as `TransportEvent::Error`, not swallowed

---

## Feedback Protocol (mandatory at end of bring-up)

Bringing up a service on msrs is also a test of msrs. After the acceptance criteria pass (and before declaring the work done), run a short retrospective over what you hit and **route every lesson to its durable home**:

| What you learned | Where it goes |
|------------------|---------------|
| msrs API friction, bug, or missing capability | GitHub issue on `goromal/msrs` labeled `bringup-feedback` (small fixes: a PR directly) |
| A cu29/statig/copper fact that cost real time (signature, feature conflict, build quirk) | PR appending to `docs/superpowers/notes/copper-statig-signatures.md` in the msrs repo |
| This skill was wrong, silent, or misleading on something | PR to anixpkgs updating this SKILL.md (use the `editing-skills` skill) |
| Service-specific decisions | The service's own SPEC.md / docs |

Rules:
- **Nothing ends its life in a session transcript.** If it surprised you, it will surprise the next agent.
- One lesson, one home — don't duplicate content across the skill and the notes file; link instead.
- File the issues/PRs as part of the bring-up work itself, not as a suggestion to the user (report what you filed).
