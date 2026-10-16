# Robot service specification template

Copy the template below into a service's `SPEC.md`. Combine sections for a small
service, and mark irrelevant concerns `N/A — <reason>`. Replace prompts with
decisions, measurable requirements, and assumptions. An unexplained method name
such as `can_start()` is not a guard specification.

Describe observable behavior before selecting Rust types or Copper tasks. Record
framework limitations in the implementation mapping; do not silently change the
required behavior to fit the current adapter. See [the tutorial](spec-tutorial.md)
for deliberately small completed examples.

## Drawing convention

- Author in draw.io or Excalidraw; commit the editable source and SVG preview with
  the spec. For example: `design/behavior.drawio` and `design/behavior.svg`.
- Use stable IDs: `S1` for a state, `T1` for a transition, `I1` for an interface,
  `R1` for a requirement and `A1` for an acceptance scenario. Scope IDs to a spec.
- Put IDs and short labels on drawings. Tables carry details. Label a transition
  `T1: event [guard] / effect`, abbreviating by reference when necessary.
- Include a legend: initial marker, composite boundary, internal event, and
  arrow meanings. In a context drawing an arrow means message flow; in a state
  drawing it means a transition. Do not use an unlabeled box for both a service
  and a state on the same view.
- An initial arrow into a composite identifies its default leaf. State whether
  re-entry uses that leaf or explicit history. Concurrent regions require their
  own coordination contract; a rectangle alone does not specify concurrency.
- Every behavioral arrow must resolve to a transition or explicitly identified
  rule. A summary view may omit detail only if it links to the detailed contract.
- Regenerate the preview after editing. Review the source, preview and tables
  together; conflicting versions block implementation of the disputed behavior.

---

```markdown
# <service-name> — Service Spec

Status: draft / ready for implementation
Owner: <design decision owner>
Spec revision: <revision>; implementation/runtime pin: <version or pending mapping>

## Purpose and boundary

What observable job does this service do? What is explicitly out of scope?
Where does it run: robot computer, controller, companion process, remote system?
List peers, hardware dependencies and required startup conditions.
Link a context drawing, or state the topology in one sentence for a trivial case.

## Authority and invariants

Who owns each actuator/command stream and each authoritative state estimate?
Who can command this service? How are manual/autonomous ownership and leases
transferred? What happens on conflicting or unauthorized commands?
Distinguish desired, accepted and observed state.

| ID | Invariant or required outcome | Applies when | Evidence |
|----|-------------------------------|--------------|----------|
| R1 | <precise condition, units and bound where applicable> | <scope> | A1 |

Define physical outcomes for stop, disable and faults rather than relying on
state names. Identify any independent controller/watchdog and what it guarantees
if this process, the transport or the computer stops executing.

## Interfaces and data semantics

| ID | Direction / peer | Meaning and fields | Delivery contract |
|----|------------------|--------------------|-------------------|
| I1 | in / <peer> | <command, observation or fault; fields> | <ordering, freshness, acknowledgement> |
| I2 | out / <peer> | <desired command or observed status; fields> | <delivery and completion semantics> |

For relevant fields specify units, ranges, coordinate frames, valid/unknown
values, clock domain and whether time means acquisition or receipt. Define
source/session identity, sequence numbers, duplicate and out-of-order handling,
freshness limits and reconnection behavior where these affect decisions.
For commands distinguish acknowledgement, rejection, completion, cancellation,
retry and idempotency. State which messages may be dropped or coalesced.
Name transport/middleware, endpoints or topics, reliability/QoS and connection
lifecycle. State how command authority is enforced at the boundary where relevant.

## Behavior

Editable source: <link>; preview: <link>.
Name the initial leaf, initial data, and startup outputs. List orthogonal modes,
their legal combinations and coordination, if present.

| State ID / name | Meaning and invariant | Entry / exit effects |
|-----------------|-----------------------|----------------------|
| S1 / <name> | <observable meaning, permitted outputs> | <effects or none> |

| ID | Source | Event | Guard | Target | Ordered effects / data updates |
|----|--------|-------|-------|--------|--------------------------------|
| T1 | S1 | I1 | <actual predicate> | S2 | <including outputs> |

Define every guard's rejection behavior. Define defaults for unexpected events.
Specify internal updates versus self-transitions, entry/exit order, composite
entry/history, and whether repeated commands reset timers or repeat effects.
Describe required and forbidden outputs, including steps with no output.
For processing/estimation/control services, also define the transformation or
algorithm contract: valid input domain, output meaning, accuracy/tolerances,
coordinate conversions and assumptions. An FSM alone does not specify the
computation performed while a state is active.

## Ordering and time

What makes one logical step? Which events can occur in it? In what order are
time advancement, observations, commands and faults applied? Resolve ties at
deadline boundaries. State the scope of priorities: events already visible in a
batch, queued traffic, or an independent path. Define which shared events every
child must defer; superstates are child-first dispatch, not automatic overrides.

| Requirement | Bound / clock / measurement points | On violation |
|-------------|------------------------------------|--------------|
| <input age, processing deadline, watchdog, output rate> | <numeric contract> | <defined response> |

Specify rates, jitter tolerance, queue capacity, overflow/backpressure policy,
and maximum work per step. Include event-to-physical-effect latency where needed.
Define clock reset/backward-time handling and time service behavior under load.
Link a sequence/timing drawing for handoffs or races that need one.

## Failure, recovery and lifecycle

| Condition | Detection / owner | Required state and outputs | Recovery / reset authority |
|-----------|-------------------|----------------------------|----------------------------|
| <dependency loss, stale data, process restart, overload, etc.> | <including deadline> | <physical meaning where relevant> | <automatic, latched, or explicit reset> |

Specify startup readiness, graceful shutdown, abrupt termination, persistent
state, cold restart and reconciliation with hardware/peer state. List which
failures this service cannot detect or handle and who owns them.

## Implementation mapping and capability gaps

Map contract IDs to stores, machines, tasks/transports and output application.
Document the actual schedule and queueing; do not derive latency from task count.
State which decisions/data remain inside the deterministic seam. Explain how
multiple observations or effects fit the adapter, including partial output-batch
application. Check tick starvation, single-output limits and state restoration
against the pinned msrs revision. List required framework work explicitly.

## Observability and replay

What state, transition cause, rejection reason, input age, queue/drop count and
deadline information must be visible? What status is authoritative?
Record initial state/configuration and versions, ordered triggers with exact
timestamps, and effects including no-output steps. Define replay start/checkpoint
semantics and the serialized output representation used for equality checks.
Prove required clock/ordering inputs are recoverable; payload-only echo replay
does not suffice for a timed service.

## Acceptance scenarios

| ID / requirements | Given | When (ordered inputs and times) | Then (state, required/forbidden effects, deadline) | Evidence level |
|-------------------|-------|---------------------------------|--------------------------------------------------|----------------|
| A1 / R1, T1 | <initial state and data> | <trace> | <checkable result> | unit / transport / simulation / hardware |

Cover normal operation, guard rejection, shared transitions from every leaf,
duplicates/reordering, exact timeout boundaries, competing events, failures and
restart where applicable. Include sustained-input timing tests and replay of
fault/timer traces. Link results when implemented; a planned test is not a pass.

## Open decisions

| Decision / assumption | Owner | Blocks implementation? | Resolution / evidence needed |
|-----------------------|-------|------------------------|------------------------------|
| <unsettled behavior or capability> | <owner> | yes/no; affected part | <next step> |
```

## Readiness review

A spec is ready when another person can predict the externally visible outcome
of its acceptance traces without inventing policy. Check that every requirement
has evidence planned, every drawn transition has defined effects/rejection, and
no unresolved decision is hidden in a guard name or framework assumption.

Human approval applies to the behavior to implement. If implementation exposes a
missing requirement, propose the specific contract change and resolve it with
the owner before implementing that behavior. Routine code organization does not
require another design approval.
