# flask-mp3server

Spawn an MP3 conversion server, powered by Python's flask library.

The server page takes an input audio file and converts it to an MP3 using the [mp3](../bash/mp3.md) tool. One can also specify a frequency transpose in terms of positive or negative half-steps.

## Usage

```bash
usage: flask_mp3server [-h] [--port PORT]

options:
  -h, --help   show this help message and exit
  --port PORT  Port to run the server on
```

