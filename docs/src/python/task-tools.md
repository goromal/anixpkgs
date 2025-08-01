# task-tools

CLI tools for managing Google Tasks.

[Repository](https://github.com/goromal/task-tools)

## Usage

```bash
Usage: task-tools [OPTIONS] COMMAND [ARGS]...

  Manage Google Tasks.

Options:
  --task-secrets-file PATH   Google Tasks client secrets file.  [default:
                             ~/secrets/google/client_secrets.json]
  --task-refresh-token PATH  Google Tasks refresh file (if it exists).
                             [default: ~/secrets/google/refresh.json]
  --task-list-id TEXT        UUID of the Task List to query.  [default:
                             MDY2MzkyMzI4NTQ1MTA0NDUwODY6MDow]
  --enable-logging BOOLEAN   Whether to enable logging.  [default: False]
  --help                     Show this message and exit.

Commands:
  clean           Delete / clean up failed timed tasks.
  delete          Delete a particular task by UUID.
  delete-by-name  Delete all tasks in a range by name.
  grader          Generate a CSV report of how consistently tasks have...
  list            List pending tasks according to a filter ∈ [all, p0,...
  put             Upload a task.
  put-spec        Read a CSV of task specifications and idempotently put...
```

### list


```bash
Usage: task-tools list [OPTIONS] FILTER

  List pending tasks according to a filter ∈ [all, p0, p1, p2, p3, late,
  ranked].

Options:
  --date [%Y-%m-%d]  Maximum due date for filtering tasks.  [default:
                     2025-07-20]
  --no-ids           Don't show the UUIDs.
  --help             Show this message and exit.
```

### delete


```bash
Usage: task-tools delete [OPTIONS] TASK_ID

  Delete a particular task by UUID.

Options:
  --help  Show this message and exit.
```

### put


```bash
Usage: task-tools put [OPTIONS]

  Upload a task.

Options:
  --name TEXT         Name of the task.  [required]
  --notes TEXT        Notes to add to the task description.
  --date [%Y-%m-%d]   Task due date.  [default: 2025-07-20]
  --until [%Y-%m-%d]  Specify an end date if for multiple days.  [default:
                      2025-07-20]
  --help              Show this message and exit.
```

### grader


```bash
Usage: task-tools grader [OPTIONS]

  Generate a CSV report of how consistently tasks have been completed within
  the specified window.

  Grading criteria:

  - P0: ... tasks must be completed same day. They will be carried over day to
  day until completed.

  - P1: ... tasks can wait until the next weekly planning session to get
  scheduled.

  - P2: ... tasks can wait until the next monthly planning session to get
  scheduled.

  Deletion / failure criteria:

  - P[0-3]: [T] ... tasks that have not be completed within the appropriate
  window.

  Migration patterns:

  - P0 manually generated tasks will be migrated to the current day.

  - P1 tasks get migrated to P0 tasks at the start of next week.

  - P2 tasks get migrated to P0 tasks at the start of next month.

Options:
  --start-date [%Y-%m-%d]  First day of the grading window.  [default:
                           2025-07-13]
  --end-date [%Y-%m-%d]    Last day of the grading window.  [default:
                           2025-07-20]
  -o, --out PATH           CSV file to generate the report in.  [default:
                           ~/data/task_grades/log.csv]
  --dry-run                Do a dry run; no task deletions.
  --help                   Show this message and exit.
```

