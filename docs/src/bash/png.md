# png

Generate PNG images from a variety of similar formats.


## Usage

```bash
usage: png [opts] inputfile outputfile
       png [opts] vacuum directory

Create a png file.

With the "vacuum" sub-command, convert every file with a supported input
extension in the given directory, preserving each filename (only the
extension changes).

Inputs:
    .png
    .gif
    .svg
    .jpeg
    .heic
    .tiff
    .random  (e.g., seed-width-height.random)

Options:
    -r|--resize [e.g., 50%]  Resize the image.
    -s|--scrub               Scrub image metadata.

Vacuum sweeps files already in .png form only when an option
above (other than verbosity) asks for a different conversion; those are
re-encoded in place. Otherwise they are skipped as a no-op.

Vacuum options (vacuum requires orchestrator on PATH):
         --orch-port PORT        Orchestrator daemon port
         --orch-priority INT     Priority for dispatched jobs

```

