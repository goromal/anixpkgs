# flask-url2mp4

Convert URL's pointing to videos to MP4's, powered by Python's flask library.

```bash
usage: flask_url2mp4 [-h]
                 [--port PORT]

optional arguments:
-h, --help   show this help message
            and exit
--port PORT  Port to run the server
            on
```

The server page takes a URL string and either uses `wget` or `youtube-dl` to download the video and convert it to MP4 using the [mp4](../bash/mp4.md) tool.

