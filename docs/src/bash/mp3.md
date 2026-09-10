# mp3

Generate (or modify) an MP3 file from similar formats.


## Usage

```bash
usage: mp3 inputfile outputfile

Create a mp3 file.

Inputs:
    .mp3
    .mp4
    .wav
    .abc

Options:
    --transpose [+- # HALF STEPS]
        Powered by https://github.com/breakfastquay/rubberband.
    --TODO

Vacuum sweeps files already in .mp3 form only when an option
above (other than verbosity) asks for a different conversion; those are
re-encoded in place. Otherwise they are skipped as a no-op.

Vacuum options (vacuum requires orchestrator on PATH):
         --orch-port PORT        Orchestrator daemon port
         --orch-priority INT     Priority for dispatched jobs

```

