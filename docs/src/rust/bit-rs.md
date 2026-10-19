# bit-rs

Machine health and regression checks with bitd and the bitctl TUI.

[Repository](https://github.com/goromal/bit-rs).
Rust executable plugins run concurrently with deadlines and journal logging.
Configure services.bitd.checks in NixOS; run bitctl to monitor health or
bitctl run --wait to execute all installed regression checks.
