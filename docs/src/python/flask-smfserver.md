# flask-smfserver

Spawn an SMF "simple music file" conversion server, powered by Python's flask library.

```bash
usage: flask_smfserver [-h] [--port PORT]

optional arguments:
-h, --help   show this help message and exit
--port PORT  Port to run the server on
```

The server page presents a text input area where you can type a song as specified by the simplified SMF music specification language:

- Notes are typed as letters with spaces between them.
- All notes are assumed to be the 4th octave unless a number is given *after* the letter.
- All notes are assumed to be quarter notes unless a number (multiplier) is given *before* the letter (or group of letters):
  - /3
  - /2
  - 2
  - 4
- Accidentals are typed *immediately after a letter*:
  - ^ = sharp
  - _ = flat
- The dash (-) means a rest. Use it like a letter.
- Multiple letters in a group form a chord.
- Begin a line with a number and colon (e.g., 1:) to specify a unique voice.

Under the hood, conversions to MP3 are done using the [abc](../bash/abc.md) and [mp3](../bash/mp3.md) tools.


