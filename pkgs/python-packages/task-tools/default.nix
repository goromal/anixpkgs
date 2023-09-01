{ buildPythonPackage, click, easy-google-auth, pkg-src }:
buildPythonPackage rec {
  pname = "task-tools";
  version = "0.0.0";
  src = pkg-src;
  propagatedBuildInputs = [ click easy-google-auth ];
  doCheck = false;
  meta = {
    description = "CLI tools for managing Google Tasks.";
    longDescription = ''
      [Repository](https://github.com/goromal/task-tools)

      ## Usage

      ```bash
      Usage: task-tools [OPTIONS] COMMAND [ARGS]...

        Manage Google Tasks.

      Options:
        --task-secrets-file PATH   Google Tasks client secrets file.  [default:
                                  /data/andrew/secrets/task/secrets.json]
        --task-refresh-token PATH  Google Tasks refresh file (if it exists).
                                  [default: /data/andrew/secrets/task/token.json]
        --enable-logging BOOLEAN   Whether to enable logging.  [default: False]
        --help                     Show this message and exit.

      Commands:
        list  List pending tasks.
        put   Upload a task.
      ```

      ### List Pending Tasks

      ```bash
      Usage: task-tools list [OPTIONS]

        List pending tasks.

      Options:
        --date [%Y-%m-%d]  Maximum due date for filtering tasks.  [default:
                          2023-07-29 22:47:50.042434]
        --help             Show this message and exit.
      ```

      ### Upload a Task

      ```bash
      Usage: task-tools put [OPTIONS]

        Upload a task.

      Options:
        --name TEXT        Name of the task.  [required]
        --notes TEXT       Notes to add to the task description.
        --date [%Y-%m-%d]  Task due date.  [default: 2023-07-29 22:48:57.751860]
        --help             Show this message and exit.
      ```
    '';
  };
}
