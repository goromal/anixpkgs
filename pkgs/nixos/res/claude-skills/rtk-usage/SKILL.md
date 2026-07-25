---
name: rtk-usage
description: Use when checking token savings analytics, diagnosing RTK hook behavior, or verifying RTK is installed correctly.
---

RTK (Rust Token Killer) is a CLI proxy that reduces token usage 60-90% on dev operations. Most commands are rewritten transparently by a Claude Code hook — you do not need to invoke `rtk` manually for normal git/bash commands.

## Meta commands (call rtk directly — not rewritten by hook)

```bash
rtk gain              # Show token savings analytics
rtk gain --history    # Show command history with per-command savings
rtk discover          # Analyze Claude Code history for missed optimization opportunities
rtk proxy <cmd>       # Run a command without RTK filtering (for debugging)
```

## Verifying installation

```bash
rtk --version         # Should print: rtk X.Y.Z
which rtk             # Confirm correct binary on PATH
```

**Name collision warning:** If `rtk gain` fails, you may have `reachingforthejack/rtk` (Rust Type Kit) installed instead of the token-killer RTK.

## Hook-based usage

All other commands (git, ls, cat, etc.) are automatically proxied through RTK by the Claude Code hook. No manual invocation needed — the savings are transparent.
