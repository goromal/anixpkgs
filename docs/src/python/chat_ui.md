# chat_ui

Logged-in chat UI for the host's local Ollama models (anix-llm's).

A model dropdown, a Clear button and streamed replies. The conversation
lives only in the browser tab; the service logs only when runs happen
and with which model.

## Usage

```bash
usage: chat_ui [-h] [--port PORT] [--subdomain SUBDOMAIN]
               [--ollama-url OLLAMA_URL] [--default-model DEFAULT_MODEL]
               --secrets-file SECRETS_FILE

Chat UI for local Ollama models

options:
  -h, --help            show this help message and exit
  --port PORT
  --subdomain SUBDOMAIN
  --ollama-url OLLAMA_URL
  --default-model DEFAULT_MODEL
                        Model preselected in the dropdown (anix-llm's default)
  --secrets-file SECRETS_FILE
                        JSON file with username, secret_key and password_hash
```

