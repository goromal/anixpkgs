# notabilify

Make any PDF document suitable for note taking in e.g., Notability.


## Usage

```bash
usage: notabilify input.pdf output.pdf

Takes a portrait PDF file and adds a large blank space to the right of every page for taking notes.

Vacuum sweeps files already in .pdf form only when an option
above (other than verbosity) asks for a different conversion; those are
re-encoded in place. Otherwise they are skipped as a no-op.

Vacuum options (vacuum requires orchestrator on PATH):
         --orch-port PORT        Orchestrator daemon port
         --orch-priority INT     Priority for dispatched jobs

```

