# Vikunja Task Management for ATS

A self-hosted task management system integrated with your ATS machine, designed for seamless collaboration between you and Claude Code.

## Overview

This setup provides:
- **Vikunja** - Open-source task management with a REST API
- **vikunja-cli** - Command-line wrapper for easy interaction
- **vikunja-mcp-server** - MCP server for native Claude Code integration
- **Standing Instructions** - Persistent guidelines that Claude always follows

## Architecture

```
┌─────────────────┐         ┌──────────────────────────────────┐         ┌─────────────────┐
│   Your Phone    │         │      ATS Machine (ats.local)     │         │ Claude Code     │
│   (Mobile UI)   │◄────────┤                                  │◄────────┤ (via MCP/CLI)   │
│                 │  HTTP   │  Nginx (Port 80/443)             │  REST   │                 │
└─────────────────┘         │    │                              │         └─────────────────┘
                            │    └─ /vikunja/ → Vikunja:3456   │
                            │                                  │
                            │  Vikunja Server (127.0.0.1:3456) │
                            │  - Serves Web UI & API           │
                            │  - SQLite DB (/var/lib/vikunja)  │
                            └──────────────────────────────────┘
```

## Deployment

### 1. Build and Deploy to ATS

From your development machine:

```bash
# Navigate to anixpkgs
cd /data/andrew/dev/packages/sources/anixpkgs

# Build the ATS configuration
nix build .#nixosConfigurations.ats.config.system.build.toplevel

# Deploy to ATS (if using nixos-rebuild)
sudo nixos-rebuild switch --flake .#ats

# Or if deploying remotely
nixos-rebuild switch --flake .#ats --target-host ats.local --use-remote-sudo
```

### 2. Initial Setup on ATS

SSH into your ATS machine:

```bash
ssh andrew@ats.local
```

Create the first Vikunja user:

```bash
# Access the Vikunja database directly to create first user
# Or use the API registration endpoint (if enabled temporarily)

# For now, you'll need to enable registration temporarily
# Edit /etc/vikunja/config.yml and set enableregistration: true
# Then restart the service
sudo systemctl restart vikunja-api

# Register your user via the web UI
# Visit http://ats.local:3457 and create an account

# After creating your account, disable registration again
# (This will happen automatically if you redeploy with the config)
```

Alternatively, access the web UI from your phone or any device on the LAN:
- `http://ats.local/vikunja/`
- `https://ats.local/vikunja/` (if SSL is configured)

### 3. Configure vikunja-cli

On the machine running Claude Code (your laptop):

```bash
# The CLI defaults to http://ats.local/vikunja/api
# You can override with VIKUNJA_URL if needed

# Login and save your token
vikunja-cli login <username> <password>

# Verify connection
vikunja-cli list-projects
```

## Usage Workflows

### Workflow 1: Creating a Project with Standing Instructions

```bash
# Create a project
PROJECT_ID=$(vikunja-cli create-project "AI Development" "Projects for Claude Code" | jq -r '.id')

# Add standing instructions that Claude should always follow
vikunja-cli create-standing-instruction $PROJECT_ID \
  "Code Style" \
  "Always use functional programming patterns. Prefer immutability. Use descriptive variable names."

vikunja-cli create-standing-instruction $PROJECT_ID \
  "Testing" \
  "Write tests for all new functions. Use property-based testing where applicable."

vikunja-cli create-standing-instruction $PROJECT_ID \
  "Documentation" \
  "Add docstrings to all public functions. Keep comments up to date with code changes."
```

### Workflow 2: Claude Code Work Session

When Claude Code starts working on your project:

```bash
# Claude reads standing instructions first
vikunja-cli get-standing-instructions

# List tasks in the project
vikunja-cli list-tasks $PROJECT_ID

# Get details of a specific task
TASK_ID=123
vikunja-cli get-task $TASK_ID

# Claude creates subtasks as it works
vikunja-cli create-task $PROJECT_ID "Implement user authentication" \
  "Create login/logout endpoints with JWT tokens"

# Claude marks tasks complete as it finishes them
vikunja-cli complete-task $TASK_ID

# Claude adds comments with progress updates
vikunja-cli add-comment $TASK_ID "Implemented JWT authentication. Tests passing."

# If Claude needs your input, it assigns the task to you
vikunja-cli assign-to-user $TASK_ID
```

### Workflow 3: Your Review and Direction (from Phone)

1. Open Vikunja web UI on your phone: `http://ats.local:3457`
2. Review tasks that Claude has assigned to you (labeled "user-assigned")
3. Add comments with feedback or clarification
4. Create new tasks or modify priorities
5. Trigger Claude to start work (via SSH or a trigger task)

### Workflow 4: Triggering Claude via SSH

From your phone using an SSH app (like Termius):

```bash
# SSH to your laptop
ssh andrew@laptop.local

# Start Claude Code on a specific project
cd /path/to/project
claude-code

# Tell Claude to work on tasks
# > "Please work on the pending tasks in Vikunja project ID 5"
```

## MCP Server Integration

For even tighter integration, configure Claude Code to use the Vikunja MCP server:

### 1. Add to Claude Code MCP Configuration

Add this to your Claude Code MCP settings (usually in `~/.config/claude-code/mcp.json`):

```json
{
  "mcpServers": {
    "vikunja": {
      "command": "vikunja-mcp-server",
      "env": {
        "VIKUNJA_URL": "http://ats.local:3456",
        "VIKUNJA_TOKEN": "your-token-here"
      }
    }
  }
}
```

### 2. Using MCP Tools in Claude Code

Once configured, Claude Code will have access to these tools:

- `vikunja_list_projects` - List all projects
- `vikunja_get_project` - Get project details
- `vikunja_list_tasks` - List tasks
- `vikunja_get_task` - Get task details
- `vikunja_create_task` - Create new task
- `vikunja_complete_task` - Mark task complete
- `vikunja_add_comment` - Add comment to task
- `vikunja_get_comments` - Get task comments
- `vikunja_get_standing_instructions` - Get standing instructions
- `vikunja_create_standing_instruction` - Create standing instruction
- `vikunja_list_user_tasks` - List tasks assigned to you
- `vikunja_assign_to_user` - Assign task to you

## Special Labels

The system uses special labels for organization:

- **claude-standing-instructions** - Tasks that represent persistent guidelines
- **user-assigned** - Tasks that need your attention/review
- **claude-assigned** - Tasks that Claude is working on

## Environment Variables

- `VIKUNJA_URL` - Vikunja API URL (default: `http://localhost:3456`)
- `VIKUNJA_TOKEN` - Authentication token (saved in `~/.config/vikunja-cli/config`)

## Troubleshooting

### Cannot connect to Vikunja

```bash
# Check if services are running on ATS
ssh andrew@ats.local
sudo systemctl status vikunja-api
sudo systemctl status vikunja-frontend

# Check logs
journalctl -u vikunja-api -f
```

### Authentication fails

```bash
# Re-login
vikunja-cli login <username> <password>

# Verify token is saved
cat ~/.config/vikunja-cli/config
```

### Tasks not showing up

```bash
# Verify project exists
vikunja-cli list-projects

# Check if you have permissions
vikunja-cli get-project $PROJECT_ID
```

## Advanced Features

### Backup and Restore

The Vikunja database is stored at `/var/lib/vikunja/vikunja.db` on the ATS machine. You can back it up with:

```bash
ssh andrew@ats.local
sudo cp /var/lib/vikunja/vikunja.db ~/backups/vikunja-$(date +%Y%m%d).db
```

### API Access

You can also interact directly with the Vikunja API:

```bash
# Get all projects
curl -H "Authorization: Bearer $VIKUNJA_TOKEN" \
  http://ats.local:3456/api/v1/projects

# Create a task
curl -X POST \
  -H "Authorization: Bearer $VIKUNJA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"New Task","description":"Task description"}' \
  http://ats.local:3456/api/v1/projects/1/tasks
```

## Security Considerations

1. **Network Access**: Vikunja is only accessible on your home LAN (not exposed to the internet)
2. **Authentication**: API tokens are required for all operations
3. **Registration**: User registration is disabled after initial setup
4. **HTTPS**: Consider adding a reverse proxy with TLS for additional security

## Future Enhancements

Potential improvements to consider:

1. **Automated Claude Triggers** - Use systemd timers to trigger Claude on specific tasks
2. **Task Templates** - Pre-defined task structures for common project types
3. **Integration with Notes Wiki** - Link tasks to your existing wiki pages
4. **Metrics and Reporting** - Track Claude's task completion rates and efficiency
5. **Mobile App** - Native iOS/Android app for better mobile experience (Vikunja has official apps)

## References

- [Vikunja Documentation](https://vikunja.io/docs/)
- [Vikunja API Docs](https://vikunja.io/docs/api/)
- [MCP Protocol](https://github.com/anthropics/model-context-protocol)
