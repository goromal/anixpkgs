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

```

