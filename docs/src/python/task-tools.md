# task-tools

CLI tools for managing Google Tasks.

[Repository](https://github.com/goromal/task-tools)

## Usage (Auto-Generated)

```bash
Usage: task-tools [OPTIONS] COMMAND [ARGS]...

  Manage Google Tasks.

Options:
  --task-secrets-file PATH   Google Tasks client secrets file.  [default:
                             /homeless-
                             shelter/secrets/google/client_secrets.json]
  --task-refresh-token PATH  Google Tasks refresh file (if it exists).
                             [default: /homeless-
                             shelter/secrets/google/refresh.json]
  --task-list-id TEXT        UUID of the Task List to query.  [default:
                             MDY2MzkyMzI4NTQ1MTA0NDUwODY6MDow]
  --enable-logging BOOLEAN   Whether to enable logging.  [default: False]
  --help                     Show this message and exit.

Commands:
  delete  Delete a particular task by UUID.
  grader  Generate a CSV report of how consistently tasks have been...
  list    List pending tasks according to a filter ∈ [all, p0, p1, p2,...
  put     Upload a task.

```

