# assistant_ui

Assistant: a web console of agent sessions rooted in the second-brain repo.

Spawns Claude/Codex sessions (tmux + ttyd) that all work in one durable
checkout of [second-brain](https://github.com/goromal/second-brain), each
preloaded with the private `assistant` skill.

## Usage

```bash
usage: assistant_ui [-h] [--port PORT] [--subdomain SUBDOMAIN]
                    [--agents AGENTS] --agent-secrets AGENT_SECRETS
                    [--repo-dir REPO_DIR] [--agent-tmux AGENT_TMUX]
                    [--agent-tmux-config AGENT_TMUX_CONFIG]
                    [--agent-session-cmd AGENT_SESSION_CMD] [--git GIT]
                    [--insecure-cookie]

Assistant: agent sessions rooted in second-brain

options:
  -h, --help            show this help message and exit
  --port PORT
  --subdomain SUBDOMAIN
                        URL prefix (e.g. '/assistant')
  --agents AGENTS       Comma-separated agent CLIs
  --agent-secrets AGENT_SECRETS
                        Secrets JSON (secret_key, password_hash)
  --repo-dir REPO_DIR
  --agent-tmux AGENT_TMUX
  --agent-tmux-config AGENT_TMUX_CONFIG
  --agent-session-cmd AGENT_SESSION_CMD
  --git GIT
  --insecure-cookie     Allow the login cookie over plain HTTP (local testing
                        only)
```

