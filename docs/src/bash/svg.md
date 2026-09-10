# svg

Generate and edit SVG files from a variety of source formats.


## Usage

```bash
usage: svg inputfile outputfile

Create an svg file.

Inputs:
    .svg
    .abc
    .pdf

Options:
    --crop    | svg [x] abc [ ] pdf [x]
    --rmtext  | svg [x] abc [ ] pdf [x]
    --poppler | svg [x] abc [ ] pdf [x]
    --scour   | svg [x] abc [x] pdf [x]
    --rmwhite | svg [x] abc [x] pdf [x]

Vacuum sweeps files already in .svg form only when an option
above (other than verbosity) asks for a different conversion; those are
re-encoded in place. Otherwise they are skipped as a no-op.

Vacuum options (vacuum requires orchestrator on PATH):
         --orch-port PORT        Orchestrator daemon port
         --orch-priority INT     Priority for dispatched jobs

```

