# mp4

Generate and edit MP4 video files using `ffmpeg`.

```
usage: mp4 inputfile outputfile

Create a mp4 file.

Inputs:
    .mp4
    .gif
    .mpeg
    .mkv
    .mov
    .avi
    .webm

Options:
    -v | --verbose               Print verbose output from ffmpeg
    -q | --quality CHAR          - for low, = for medium, + for high bit rate quality
    -w | --width WIDTH           Constrain the video width (pixels)
    -l | --label "STR"           Add label to bottom left corner of video
    -f | --fontsize INT          Font size for added text
    -c | --crop INT:INT:INT:INT  Crop video (pre-labeling) W:H:X:Y
    -s | --start TIME            INITIAL time: [HH:]MM:SS[.0]
    -e | --end TIME              FINAL time: [HH:]MM:SS[.0]

```

