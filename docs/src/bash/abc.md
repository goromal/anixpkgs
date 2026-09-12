# abc

Generate [abc music files](https://abcnotation.com/) from similar formats.


## Usage

```bash
usage: abc inputfile outputfile

Create an abc file.

Inputs:
    .smf
    .midi

Vacuum sweeps files already in .abc form only when an option
above (other than verbosity) asks for a different conversion; those are
re-encoded in place. Otherwise they are skipped as a no-op.

Vacuum options (vacuum requires orchestrator on PATH):
         --orch-port PORT        Orchestrator daemon port
         --orch-priority INT     Priority for dispatched jobs

```

