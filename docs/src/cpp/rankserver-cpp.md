# rankserver-cpp

A portable webserver for RESTfully ranking files via binary manual comparisons.

[Repository](https://github.com/goromal/rankserver-cpp)

## Usage

```
Options:
  -h [ --help ]         print usage
  -p [ --port ] arg     port to serve on (default: 4000)
  -d [ --data-dir ] arg data directory to process (default: ./data)
```

Spins up a [crowcpp](./crowcpp.md) webserver (on the specified port) whose purpose is to help a user
rank files in the chosen `data-dir` directory via manual binary comparisons. The ranking is done via
an incremental "RESTful" sorting strategy implemented within the [sorting](./sorting.md) library. State
is created and maintained within the `data-dir` directory so that the ranking exercise can pick back up
where it left off between different spawnings of the server. At this point, only the ranking of `.txt` and
`.png` files is possible; other file types in `data-dir` will be ignored.

