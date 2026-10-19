# Machine profiles

Profiles select capabilities under `machines.features`. Every profile must set
every `<feature>.enable` in [features/catalog.nix](features/catalog.nix) explicitly,
including false choices. Agent CLI selection is the required
`agents.frameworks` list; use `[]` for none. Feature switches have no defaults.
Adding a capability therefore requires updating all four PC profiles.

`machines.base` contains machine facts and shared configuration: architecture,
home directory, NixOS state version, interfaces, cloud directories, and remote
builders. Hardware files select drivers and devices. Host configurations can
explicitly override profile choices with `lib.mkForce` for host-specific
capabilities (see personal-dell.nix).

Feature modules own the service enablement and integration needed to deliver a
capability. Profiles should not set the corresponding lower-level service
enable switches as well. Backend options remain available for tuning packages,
paths, models, and hardware parameters.

Examples:

- `agentUi.enable` starts both terminal services and registers nginx routes.
  It requires a nonempty `agents.frameworks`; development tools do not enable it.
- `gpu.enable` installs CUDA tooling. `notebooks.enable` and
  `imageGeneration.enable` independently select Launchpad and ComfyUI/Cozy.
  Notebooks register their sync job automatically; it runs only when the
  orchestrator is enabled.
- `gameStreaming.enable` selects Sunshine and Sunset together.
- `orchestrator.enable` controls the daemon, UI, trigger command, scheduled
  jobs, timers, and blacklist directory. Jobs may remain configured while off.
- `folio.enable` selects the backend. Its role defaults to spoke; the ATS
  profile selects hub. Its desktop shell follows the desktop feature by default.
- `desktop.enable` includes GNOME's normal desktop dependencies, printing,
  and the captive-portal browser. `headsetAudio.enable` adds the personal
  PipeWire/Bluetooth headset tuning; it is not a master audio switch.

Shared reverse-proxy enablement is an internal dependency contributed by web
services. Profiles do not set `runWebServer`. A landing-page service with a
dedicated public port sets `webServices.*.port`; descriptions are display text.

The deliberately shared baseline includes primary-user setup, SSH,
NetworkManager, Avahi discovery, core shell/system tools, fonts, journald policy,
and the existing TCP 4444 firewall allowance. Hardware-specific boot and Jetson
power-management setup follows machine type. Application servers never do.

Orchestrator jobs and cloud directories use typed submodules: unknown fields
are rejected. Jobs support `name`, `jobShellScript`, `timerCfg`,
`readWritePaths`, `execStartPre`, and `logTags`. Parameters have defaults where
appropriate; feature choices do not.

## Validation

Run with the repository's NIXOS_VERSION channel:

```sh
python3 scripts/test_profile_contracts.py
python3 scripts/smoke_test_profiles.py
```

The contract suite evaluates all PC profiles, including a synthetic workstation,
and all concrete PC configurations. It checks service sets, units, routes,
firewall ports, feature isolation, schema errors, and NixOS assertions.
The smoke suite checks pairwise combinations of independent feature switches.
Both temporarily use local package definitions and restore dependencies.nix
afterward; do not run them concurrently in the same checkout.

This migration removes the old `machines.base` feature booleans and `isATS`.
Use `features.orchestrator.jobs` and `features.orchestrator.extraPackages`
instead of `base.timedOrchJobs` and `base.extraOrchestratorPackages`.
Launchpad's Python packages now belong to `services.launchpad.pythonPackages`.
The unused `notesWikiPort` option is removed; the wiki uses the shared webserver.
