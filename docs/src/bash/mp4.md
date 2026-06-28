# mp4

Generate and edit MP4 video files using `ffmpeg`.


## Usage

```bash
usage: mp4 [opts] inputfile outputfile
       mp4 [opts] vacuum directory

Create a mp4 file.

With the "vacuum" sub-command, convert every file with a supported input
extension in the given directory, preserving each filename (only the
extension changes).

Inputs:
    .mp4
    .gif
    .mpeg
    .mkv
    .mov
    .avi
    .webm
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

```

