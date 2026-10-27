{
  buildPythonPackage,
  setuptools,
  pillow,
  pytestCheckHook,
  ffmpeg-headless,
  whisper-cpp,
  yt-dlp,
  pkg-src,
}:
buildPythonPackage rec {
  pname = "media2notes";
  version = "0.1.0";
  pyproject = true;
  build-system = [ setuptools ];
  src = "${pkg-src}/media2notes";
  propagatedBuildInputs = [ pillow ];
  nativeCheckInputs = [ pytestCheckHook ];
  makeWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    "${yt-dlp}/bin"
    "--prefix"
    "PATH"
    ":"
    "${ffmpeg-headless}/bin"
    "--prefix"
    "PATH"
    ":"
    "${whisper-cpp}/bin"
  ];
  meta = {
    description = "Turn a YouTube video or podcast URL into a local transcript + key-frames folder for note taking.";
    longDescription = ''
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
    '';
    autoGenUsageCmd = "--help";
  };
}
