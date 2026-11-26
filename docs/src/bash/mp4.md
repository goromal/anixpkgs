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

With --upscale, the output is a restored, upscaled copy (1080p tall by
default) and the source is always kept. Vacuum writes NAME_upscaled.mp4
next to each source, skips sources whose _upscaled output already exists
(so an interrupted sweep resumes), and runs model jobs one at a time.

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
    -u | --upscale MODE          Restore + upscale old video. MODE:
                                   classic  ffmpeg only: auto border crop,
                                            chroma realignment, smoothed
                                            white balance, denoise, deblock,
                                            aspect fix, Lanczos upscale,
                                            sharpen
                                   model    same front end + Real-ESRGAN on
                                            a Vulkan GPU (video2x)
         --stabilize             (upscale) Two-pass camera-shake removal
         --keep-color            (upscale) Skip the automatic white balance
         --model NAME            (upscale model) fast (default) or quality,
                                 or a video2x realesrgan model name
         --gpu INDEX             (upscale model) ncnn GPU index (default:
                                 first discrete GPU)
         --host HOST             (upscale model) Run the model pipeline on
                                 HOST over SSH (e.g. atorgesen-dell.local)

Vacuum sweeps files already in .mp4 form only when an option
above (other than verbosity) asks for a different conversion; those are
re-encoded in place. Otherwise they are skipped as a no-op.

Vacuum options (vacuum requires orchestrator on PATH):
         --orch-port PORT        Orchestrator daemon port
         --orch-priority INT     Priority for dispatched jobs

```

