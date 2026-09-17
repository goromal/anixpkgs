# sunnyside

File scrambler.

Written in Rust. [Repository](https://github.com/goromal/sunnyside)

## Usage

```bash
Make some scrambled eggs.

Usage: sunnyside [OPTIONS] [COMMAND]

Commands:
  bu    Backup: compress, scramble, and store a file or directory tree
  rs    Restore: descramble and decompress a backup
  help  Print this message or the help of the given subcommand(s)

Options:
  -t, --target <TARGET>  File target (legacy mode)
  -s, --shift <SHIFT>    Shift amount (legacy mode)
  -k, --key <KEY>        Scramble key (legacy mode)
  -h, --help             Print help
  -V, --version          Print version
```

