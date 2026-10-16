# Writing a small service spec

These three examples teach the contract a drawing needs around it. They are
specifications with planned acceptance tests, not implemented services. They use
virtual indicators and monitoring so the first exercise has no motor-control or
physical-stop policy to decide. Timing values are teaching choices, not robot
defaults.

Open each `behavior.drawio` in draw.io to edit it, or read its SVG preview beside
the spec. You can author your own version in Excalidraw using the same IDs and
contracts; the editor does not change the semantics. The examples use draw.io so
there is only one editable source per drawing to maintain.

## 1. Specify what a command means

Read [01 — A virtual indicator](examples/01-indicator/SPEC.md).

It has two states and one input. The useful design decisions are small: `Set`
expresses a desired value, repeated commands return status without re-entering
the state, and restart begins off. The output reports logical state; it does not
claim that a physical lamp changed.

Trace `Set(on), Set(on), Set(off)` through the drawing and table. You should be
able to predict all three outputs. Then compare with A2. This is the minimum
useful exercise: state names plus arrows would not settle duplicate handling.

## 2. Add a shared mode

Read [02 — An enabled indicator](examples/02-enabled-indicator/SPEC.md).

`enabled` contains `off` and `on`. `Disable` applies to both children. The spec
also answers questions a composite box leaves open: enabling starts off,
re-enabling preserves the current child, and a `Set` while disabled is rejected.

Trace `Enable, Set(on), Disable, Set(on), Enable`. Compare with A1–A4.
Notice that disabling an indicator is a logical operation here. A motor service
would additionally need to define its physical stopping behavior and authority.

The child-first rule matters: both enabled children must defer `Disable` without
emitting their own status first. T4 is implemented once but exercised from both
leaves. This is where hierarchy removes duplication without defining priority
between separate queued commands.

## 3. Add time and stale data

Read [03 — A telemetry freshness monitor](examples/03-freshness-monitor/SPEC.md).

This example consumes an explicit timed cycle containing an optional sample.
That makes the contract's ordering visible and avoids relying on idle-only ticks.
The spec separates sample acquisition time from cycle time and says exactly what
happens at the freshness boundary.

Trace a sample acquired at 0 ms, then cycles at 90 and 100 ms without a sample.
Now replace the last cycle with a sample acquired at 100 ms. Compare with A1–A3:
the new observation is applied before the cycle's freshness decision.

This also introduces a real implementation gap: the stock adapter does not
produce the promised periodic cycle input. The spec identifies the work required
without pretending that a timer guard fixes scheduling. Its output is monitor
status; consumers still need their own policy when the monitor disappears.

## Build your own next

Copy [the template](service-spec-template.md), then start with:

1. One sentence defining responsibility and authority.
2. A context drawing showing peers and message direction.
3. A behavior drawing with initial state and stable state/transition IDs.
4. Transition/interface tables that settle effects, rejection and data meaning.
5. Three concrete traces: normal operation, one conflict or timeout, and restart.

Then fill the remaining applicable contracts. For a more complex robot service,
pay particular attention to ownership handoff, desired versus observed state,
coordinate frames, stale inputs, bounded response time, and who acts when this
process cannot run. Mark unknowns as decisions to resolve instead of guessing.

Bring that draft and its editable drawing to the next design review. The first
implementation step is to check that the chosen msrs revision can support its
contracts, then turn the acceptance traces into tests at the pure seam.
