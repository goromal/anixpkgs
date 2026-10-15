# mp4

Generate and edit MP4 video files using `ffmpeg`.


## Usage

```bash
usage: mp4 [opts] inputfile outputfile
       mp4 [opts] vacuum directory

Create a mp4 file.

With the "vacuum" sub-command, dispatch an orchestrator job for every file
with a supported input extension -- excluding .mp4 itself -- in the given
directory, preserving each filename (only the extension changes). Every
option above applies to each dispatched conversion, and each source file is
removed only once its conversion has succeeded.

Inputs:
    .mp4
    .gif
    .mpeg
    .mkv
    .mov
    .avi
    .webm
    .flv
    .random (e.g., seed-width-height-frames.random)

Options:
    -v | --verbose               Print verbose output from ffmpeg
    -m | --mute                  Remove audio
    -q | --quality CHAR          - for low, = for medium, + for high bit rate quality
    -w | --width WIDTH           Constrain the video width (pixels)
    -l | --label "STR"           Add label to bottom left corner of video
    -f | --fontsize INT          Font size for added text
    -c | --crop INT:INT:INT:INT  Crop video (pre-labeling) W:H:X:Y
    -s | --start TIME            INITIAL time: [HH:]MM:SS[.0]
    -e | --end TIME              FINAL time: [HH:]MM:SS[.0]

Vacuum sweeps files already in .mp4 form only when an option
above (other than verbosity) asks for a different conversion; those are
re-encoded in place. Otherwise they are skipped as a no-op.

Vacuum options (vacuum requires orchestrator on PATH):
         --orch-port PORT        Orchestrator daemon port
         --orch-priority INT     Priority for dispatched jobs

```

