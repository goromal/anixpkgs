# agent_ui

Web console for devshell workspaces and agent terminals.

Provides an authenticated browser interface for managing devshell
workspaces and attaching to tmux-backed shell, Claude, and Codex sessions.

## Usage

```bash
usage: agent-ui [-h] [--port PORT] [--subdomain SUBDOMAIN] [--devrc DEVRC]
                [--agent AGENTS] [--token-file TOKEN_FILE]
                [--tmux-bin TMUX_BIN] [--session-command SESSION_COMMAND]
                [--workspace-command WORKSPACE_COMMAND] [--history HISTORY]

Workspace-aware terminal agent launcher

options:
  -h, --help            show this help message and exit
  --port PORT
  --subdomain SUBDOMAIN
  --devrc DEVRC
  --agent AGENTS
  --token-file TOKEN_FILE
  --tmux-bin TMUX_BIN
  --session-command SESSION_COMMAND
  --workspace-command WORKSPACE_COMMAND
  --history HISTORY
```

