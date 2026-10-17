---
name: bitd-plugins
description: Add, configure, test, or debug Rust health and regression plugins for bitd and bitctl in bit-rs, aapis, and anixpkgs.
---

# BIT plugins

Use the workspace's `bit-rs` repository for plugin implementations and
`anixpkgs` for packaging, profile selection, and machine-specific settings.
The gRPC contract lives in `aapis/protos/aapis/bit/v1/bit.proto`; ordinary new
plugins do not need a contract change.

## Interface

Plugins are separate Rust executables implementing `bit_rs::plugin::BitCheck`.
Derive `serde::Deserialize` with `deny_unknown_fields` on the configuration
type, implement async `check(&self) -> anyhow::Result<()>` and
`remediation(&self) -> String`, and call
`bit_rs::plugin::run::<Config>().await` from the Tokio main function. See
`src/bin/internet.rs` for the smallest example.

The executable receives one JSON object on stdin, logs to stdout (inherited
by bitd's journal), and exits zero for pass or nonzero for failure.
`remediation()` returns concrete, config-aware plain-text steps for a failing
check (commands to run, likely causes); bitd fetches it once at startup via
`<plugin> --remediation` (same stdin JSON, no check runs) and bitctl shows it
under the highlighted check. Keep it short enough to read in a terminal panel. Never print
tokens or secrets. Reference credential files in configuration; do not embed
credentials in Nix store files. The daemon gives each invocation a process
group, enforces a wall-clock timeout, and kills helpers on completion or stop.
Do not detach helpers from that group.

Health checks require a rate and must be lightweight. Regression checks run
only on explicit request. Different checks run concurrently; a check never
overlaps itself. Keep test fixtures deterministic and correlate remote results
to the submitted job ID. Timeouts kill local processes, but a remote job may
continue: implement targeted cleanup where the remote API supports it.

## Packaging and selection

Add the binary in `bit-rs/Cargo.toml`. Add a plugin output and install mapping
in `anixpkgs/pkgs/rust-packages/bit-rs/default.nix`, and register defaults in
`anixpkgs/pkgs/modules/bitd/module.nix`. Only the main output contains bitd and
bitctl; plugin output paths enter the system closure when selected.

Modules append string names to `services.bitd.checks`. Definitions live under
`services.bitd.plugins.<name>`: `kind`, absolute `command`, `timeoutMs`,
`rateHz` (health only), and JSON-compatible `settings`. Use `lib.mkDefault` for
tunable defaults. Add checks to the narrowest applicable profile/module.
The daemon reads its configuration at startup; NixOS restarts it when the
generated configuration changes.

## Verification

Set `AAPIS_PROTO_DIR` to the aapis checkout's `protos` directory when it is not
a sibling of bit-rs. Keep Cargo build output in the workspace data directory.
Run `cargo test --locked` and `cargo clippy --all-targets -- -D warnings` with
Rust, a C compiler, and protoc available. Cover pass, failure, malformed
configuration, timeout, and remote-response handling where relevant using
offline fixtures. Avoid running expensive regression jobs as part of builds.

Build the Nix package and evaluate the affected profile's generated
`/etc/bitd.json`. Follow the workspace-development and anixpkgs-deploy workflow
for branches, remote input pins, deployment, and PRs. On the target machine:

```sh
bitctl list --json
bitctl run <name> --wait
journalctl -u bitd --since '5 minutes ago'
```

`bitctl` with no subcommand opens the TUI. `bitctl run --wait` runs all
regressions, so name the check when testing one plugin. The gRPC server binds
to loopback; use SSH port forwarding to inspect another machine. A failing
check may indicate an actual machine problem; distinguish that from runner
failure and record live-test limitations accurately.
