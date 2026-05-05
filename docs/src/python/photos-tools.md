# photos-tools

CLI tools for managing Google Photos.

[Repository](https://github.com/goromal/photos-tools)

For your photos management, follow these steps:

1. Favorite *only* the media that you would like to "thin out"
2. On a computer with space, run the clean method
3. Move the whole Favorites directory to the trash

## Usage

```bash
Usage: photos-tools [OPTIONS] COMMAND [ARGS]...

  Manage Google Photos.

Options:
  --photos-secrets-file PATH   Google Photos client secrets file.  [default:
                               ~/secrets/google/client_secrets.json]
  --photos-refresh-token PATH  Google Photos refresh file (if it exists).
                               [default: ~/secrets/google/refresh.json]
  --enable-logging BOOLEAN     Whether to enable logging.  [default: False]
  --help                       Show this message and exit.

Commands:
  clean  Download favorited photos so that you can later delete them from...
```

### clean


```bash
Usage: photos-tools clean [OPTIONS]

  Download favorited photos so that you can later delete them from the cloud.

Options:
  --output-dir PATH  Directory to download the media to.
  --dry-run          Dry run only.
  --help             Show this message and exit.
```

