# cozy

One-pager UI for generating images with ComfyUI workflows.


## Usage

```bash
usage: cozy [-h] [--port PORT] [--subdomain SUBDOMAIN]
            [--comfyui-url COMFYUI_URL] [--state-dir STATE_DIR]
            [--workflow-dir WORKFLOW_DIR] [--workflows WORKFLOWS]
            [--input-dir INPUT_DIR]

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
```

