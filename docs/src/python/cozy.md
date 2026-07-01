# cozy

One-pager UI for generating images with ComfyUI workflows.


## Usage

```bash
usage: cozy [-h] [--port PORT] [--subdomain SUBDOMAIN]
            [--comfyui-url COMFYUI_URL] [--state-dir STATE_DIR]
            [--workflow-dir WORKFLOW_DIR] [--workflows WORKFLOWS]
            [--input-dir INPUT_DIR] [--output-dir OUTPUT_DIR]
            --secrets-file SECRETS_FILE
            [--comfyui-restart-cmd COMFYUI_RESTART_CMD]

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
  --secrets-file SECRETS_FILE
                        Path to JSON file with secret_key and password_hash
  --comfyui-restart-cmd COMFYUI_RESTART_CMD
                        Command run to restart ComfyUI (e.g. 'systemctl
                        restart comfyui.service'); empty hides the restart
                        button
```

