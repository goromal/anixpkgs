# cozy

One-pager UI for generating images with ComfyUI workflows.


## Usage

```bash
usage: cozy [-h] [--port PORT] [--subdomain SUBDOMAIN]
            [--comfyui-url COMFYUI_URL] [--state-dir STATE_DIR]
            [--workflow-dir WORKFLOW_DIR] [--workflows WORKFLOWS]
            [--input-dir INPUT_DIR] [--output-dir OUTPUT_DIR]
            [--prompt-db-dir PROMPT_DB_DIR] --secrets-file SECRETS_FILE
            [--comfyui-restart-cmd COMFYUI_RESTART_CMD] [--rest-gap REST_GAP]

options:
  -h, --help            show this help message and exit
  --port PORT           Port to run the server on
  --subdomain SUBDOMAIN
                        Subdomain for a reverse proxy
  --comfyui-url COMFYUI_URL
                        Base URL of the ComfyUI server
  --state-dir STATE_DIR
                        Directory for persisted cozy state
  --workflow-dir WORKFLOW_DIR
                        Directory containing <name>.api.json workflow files
  --workflows WORKFLOWS
                        Comma-separated workflow names
  --input-dir INPUT_DIR
                        Directory of selectable input images (default
                        <workflow-dir>/input)
  --output-dir OUTPUT_DIR
                        Directory of selectable output images for edit
                        workflows (default <workflow-dir>/output)
  --prompt-db-dir PROMPT_DB_DIR
                        Directory of saved prompt .txt files (default <state-
                        dir>/prompts)
  --secrets-file SECRETS_FILE
                        Path to JSON file with secret_key and password_hash
  --comfyui-restart-cmd COMFYUI_RESTART_CMD
                        Command run to restart ComfyUI (e.g. 'systemctl
                        restart comfyui.service'); empty hides the restart
                        button
  --rest-gap REST_GAP   Seconds to rest between queued jobs
``````bash
usage: cozyctl [-h] [--url URL] [--token TOKEN] [--token-file TOKEN_FILE]
               {queue,status,start,stop} ...

Queue cozy image-generation jobs from the command line.

positional arguments:
  {queue,status,start,stop}
    queue               queue one generator job per prompt file
    status              show the queue
    start               start draining the queue
    stop                stop after the current job

options:
  -h, --help            show this help message and exit
  --url URL             base URL of the cozy app, e.g.
                        http://myhost.local/cozy (env COZY_URL; set for you on
                        hosts running cozy)
  --token TOKEN         API token (env COZY_TOKEN; prefer --token-file)
  --token-file TOKEN_FILE
                        file holding the API token (default
                        ~/secrets/flask/cozy-api-token)
```

