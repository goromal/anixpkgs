# msrs

Deterministic microservice conventions for Rust: pure stores + statig FSMs packaged as copper-rs tasks.

Written in Rust. [Repository](https://github.com/goromal/msrs)

Successor to [mscpp](../cpp/mscpp.md). Provides `FsmTask` (a generic
[copper-rs](https://github.com/copper-project/copper-rs) transform task that
drives a pure `Store` + [statig](https://github.com/mdeloof/statig) state
machine), a `Transport` plug-in trait with a real-time-configurable driver
thread, and ingress/egress bridge tasks for wiring transports into a copper
task graph. Deterministic replay from copper's unified log is exercised
end-to-end by the bundled echo example.

