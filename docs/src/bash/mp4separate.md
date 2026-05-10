# mp4separate

Split an MP4 file into N equal segments or segments of a given length.


## Usage

```bash
usage: mp4separate [options] <MP4-sourcefile>

Split an MP4 file into segments.

By default, splits via stream copy (fast, lossless) which snaps cuts to the
nearest keyframe. Use --reencode for precise cuts at the cost of speed and
a re-encode.

Options:
-h | --help          Print out the help documentation.
-n | --num-segments  Split into N equally sized segments.
-l | --seg-length    Split into segments of length MM:SS (e.g. 01:30).
-r | --reencode      Re-encode with forced keyframes for precise splits.
-v | --verbose       Print verbose output from ffmpeg

```

