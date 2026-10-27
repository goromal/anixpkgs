# media2notes

Turn a YouTube video or podcast URL into a local transcript + key-frames folder for note taking.

Writes `~/data/media2notes/<extractor>-<id>/` containing `meta.json`,
`transcript.md` (`[mm:ss] text` lines with `## [mm:ss] Chapter`
headings), `frames/<seconds>.jpg` and `source.txt`. Transcripts come
from yt-dlp captions (manual over auto) when available, otherwise from
offline, CPU-only whisper.cpp. The `small.en` model (~490 MB) is not
part of the package: it is downloaded once on first Whisper use, pinned by
URL and sha256, into `~/.cache/media2notes/models/`
(`$MEDIA2NOTES_WHISPER_MODEL` overrides the path). Frames are scene-change plus 60 s
samples, dHash-deduplicated and capped at 40; they are skipped for
audio-only sources. Downloaded media is always deleted. Reruns reuse the
folder and skip finished steps. The CLI does no AI or Notion work; an
assistant session reads the folder to draft notes.

Design: [second-brain media intake spec](https://github.com/goromal/second-brain/blob/main/docs/specs/2026-10-26-media-intake-design.md)

## Usage

```bash
usage: media2notes [-h] [--frames {auto,on,off}] [--model MODEL]
                   [--force-whisper] [--out-root OUT_ROOT]
                   url

Turn a YouTube video or podcast URL into a local folder holding a timestamped
transcript (captions, else offline whisper.cpp), the frames that matter, and
metadata. Prints the folder path as the last stdout line. Reruns reuse the
folder and skip finished steps.

positional arguments:
  url                   media URL (anything yt-dlp supports)

options:
  -h, --help            show this help message and exit
  --frames {auto,on,off}
                        extract key frames: auto = only when the source has
                        video (default: auto)
  --model MODEL         whisper.cpp model name or ggml file path, used when
                        there are no captions; pinned models are downloaded
                        once to ~/.cache/media2notes/models (default:
                        small.en; $MEDIA2NOTES_WHISPER_MODEL overrides the
                        path)
  --force-whisper       ignore captions and (re)transcribe with whisper.cpp
  --out-root OUT_ROOT   parent directory for output folders (default:
                        ~/data/media2notes)
```

