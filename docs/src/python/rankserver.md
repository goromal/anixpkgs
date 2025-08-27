# rankserver

A portable webserver for ranking files via binary manual comparisons, powered by Python's flask library.

Spins up a flask webserver (on the specified port) whose purpose is to help a user rank files in the chosen `data-dir` directory via manual binary comparisons. The ranking is done via an incremental "RESTful" sorting strategy implemented within the [pysorting](./pysorting.md) library. State is created and maintained within the `data-dir` directory so that the ranking exercise can pick back up where it left off between different spawnings of the server. At this point, only the ranking of `.txt` and `.png` files is possible; other file types in `data-dir` will be ignored.    

## Usage

```bash
usage: rankserver [-h] [--port PORT] [--data-dir DATA_DIR]

options:
  -h, --help           show this help message and exit
  --port PORT          Port to run the server on
  --data-dir DATA_DIR  Directory containing the rankable elements
```

