#!/usr/bin/env bash
# Vikunja CLI wrapper for Claude Code integration
# This script provides a simple interface for Claude Code to interact with Vikunja's REST API

set -euo pipefail

# Configuration
VIKUNJA_URL="${VIKUNJA_URL:-http://ats.local/vikunja}"
VIKUNJA_TOKEN="${VIKUNJA_TOKEN:-}"
VIKUNJA_CONFIG="${HOME}/.config/vikunja-cli/config"

# Special label for standing instructions
STANDING_INSTRUCTIONS_LABEL="claude-standing-instructions"
CLAUDE_ASSIGNED_LABEL="claude-assigned"
USER_ASSIGNED_LABEL="user-assigned"

# Load token from config if it exists
if [[ -f "$VIKUNJA_CONFIG" ]]; then
  source "$VIKUNJA_CONFIG"
fi

# Helper function to make API calls
api_call() {
  local method="$1"
  local endpoint="$2"
  local data="${3:-}"

  if [[ -z "$VIKUNJA_TOKEN" ]]; then
    echo "Error: VIKUNJA_TOKEN not set. Run 'vikunja-cli login' first." >&2
    exit 1
  fi

  local curl_args=(-X "$method" -H "Authorization: Bearer $VIKUNJA_TOKEN" -H "Content-Type: application/json" -s)

  if [[ -n "$data" ]]; then
    curl_args+=(-d "$data")
  fi

  curl "${curl_args[@]}" "${VIKUNJA_URL}/api/v1${endpoint}"
}

# Command implementations
cmd_login() {
  local username="$1"
  local password="$2"

  local payload
  payload=$(jq -n --arg u "$username" --arg p "$password" '{"username":$u,"password":$p}')
  local response=$(curl -X POST -H "Content-Type: application/json" \
    -d "$payload" \
    -s "${VIKUNJA_URL}/api/v1/login")

  local token=$(echo "$response" | jq -r '.token // empty')

  if [[ -z "$token" ]]; then
    echo "Login failed. Response: $response" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$VIKUNJA_CONFIG")"
  echo "VIKUNJA_TOKEN=\"$token\"" > "$VIKUNJA_CONFIG"
  chmod 600 "$VIKUNJA_CONFIG"

  echo "Successfully logged in. Token saved to $VIKUNJA_CONFIG"
}

cmd_list_projects() {
  api_call GET "/projects" | jq -r '.[] | "\(.id)\t\(.title)\t\(.description // "")"'
}

cmd_get_project() {
  local project_id="$1"
  api_call GET "/projects/$project_id" | jq '.'
}

cmd_list_tasks() {
  local project_id="${1:-}"

  if [[ -n "$project_id" ]]; then
    api_call GET "/projects/$project_id/tasks" | jq -r '.[] | "\(.id)\t\(.done)\t\(.title)"'
  else
    # List all tasks across all projects
    local projects=$(api_call GET "/projects" | jq -r '.[].id')
    for pid in $projects; do
      api_call GET "/projects/$pid/tasks" | jq -r --arg pid "$pid" '.[] | "\(.id)\t\($pid)\t\(.done)\t\(.title)"'
    done
  fi
}

cmd_get_task() {
  local task_id="$1"
  api_call GET "/tasks/$task_id" | jq '.'
}

cmd_create_task() {
  local project_id="$1"
  local title="$2"
  local description="${3:-}"

  local escaped_title
  escaped_title=$(echo "$title" | jq -Rs .)
  local data="{\"title\":$escaped_title"
  if [[ -n "$description" ]]; then
    # Escape newlines and quotes in description
    description=$(echo "$description" | jq -Rs .)
    data="$data,\"description\":$description"
  fi
  data="$data}"

  api_call POST "/projects/$project_id/tasks" "$data" | jq '.'
}

cmd_update_task() {
  local task_id="$1"
  shift
  local updates="$@"

  # Build JSON from key=value pairs
  local data="{"
  local first=true
  for update in $updates; do
    local key="${update%%=*}"
    local value="${update#*=}"

    if [[ "$first" == true ]]; then
      first=false
    else
      data="$data,"
    fi

    # Handle boolean and numeric values
    if [[ "$value" == "true" ]] || [[ "$value" == "false" ]] || [[ "$value" =~ ^[0-9]+$ ]]; then
      data="$data\"$key\":$value"
    else
      data="$data\"$key\":\"$value\""
    fi
  done
  data="$data}"

  api_call POST "/tasks/$task_id" "$data" | jq '.'
}

cmd_complete_task() {
  local task_id="$1"
  cmd_update_task "$task_id" "done=true"
}

cmd_add_comment() {
  local task_id="$1"
  local comment="$2"

  # Escape the comment text
  comment=$(echo "$comment" | jq -Rs .)

  api_call PUT "/tasks/$task_id/comments" "{\"comment\":$comment}" | jq '.'
}

cmd_get_comments() {
  local task_id="$1"
  api_call GET "/tasks/$task_id/comments" | jq -r '.[] | "[\(.created)] \(.author.username): \(.comment)"'
}

cmd_list_labels() {
  api_call GET "/labels" | jq -r '.[] | "\(.id)\t\(.title)\t\(.hex_color)"'
}

cmd_create_label() {
  local title="$1"
  local color="${2:-#1973ff}"

  api_call PUT "/labels" "{\"title\":\"$title\",\"hex_color\":\"$color\"}" | jq '.'
}

cmd_add_label_to_task() {
  local task_id="$1"
  local label_id="$2"

  api_call PUT "/tasks/$task_id/labels" "{\"label_id\":$label_id}" | jq '.'
}

cmd_get_standing_instructions() {
  # Get all tasks with the standing instructions label
  local label_id=$(api_call GET "/labels" | jq -r ".[] | select(.title==\"$STANDING_INSTRUCTIONS_LABEL\") | .id")

  if [[ -z "$label_id" ]]; then
    echo "No standing instructions label found. Create tasks with label '$STANDING_INSTRUCTIONS_LABEL' to define standing instructions."
    return
  fi

  # Find tasks with this label across all projects
  local projects=$(api_call GET "/projects" | jq -r '.[].id')
  for pid in $projects; do
    api_call GET "/projects/$pid/tasks" | jq -r --arg lid "$label_id" '.[] | select(.labels[]?.id == ($lid | tonumber)) | "## \(.title)\n\n\(.description)\n"'
  done
}

cmd_create_standing_instruction() {
  local project_id="$1"
  local title="$2"
  local instruction="$3"

  # Ensure the standing instructions label exists
  local label_id=$(api_call GET "/labels" | jq -r ".[] | select(.title==\"$STANDING_INSTRUCTIONS_LABEL\") | .id")

  if [[ -z "$label_id" ]]; then
    label_id=$(cmd_create_label "$STANDING_INSTRUCTIONS_LABEL" "#ff9800" | jq -r '.id')
  fi

  # Create the task
  local task=$(cmd_create_task "$project_id" "$title" "$instruction")
  local task_id=$(echo "$task" | jq -r '.id')

  # Add the standing instructions label
  cmd_add_label_to_task "$task_id" "$label_id"

  echo "Standing instruction created with ID: $task_id"
}

cmd_list_user_tasks() {
  # Get all tasks assigned to the user (with user-assigned label)
  local label_id=$(api_call GET "/labels" | jq -r ".[] | select(.title==\"$USER_ASSIGNED_LABEL\") | .id")

  if [[ -z "$label_id" ]]; then
    echo "No user-assigned tasks found."
    return
  fi

  local projects=$(api_call GET "/projects" | jq -r '.[].id')
  for pid in $projects; do
    api_call GET "/projects/$pid/tasks" | jq -r --arg lid "$label_id" '.[] | select(.labels[]?.id == ($lid | tonumber)) | select(.done == false) | "\(.id)\t\(.title)"'
  done
}

cmd_assign_to_user() {
  local task_id="$1"

  # Ensure the user-assigned label exists
  local label_id=$(api_call GET "/labels" | jq -r ".[] | select(.title==\"$USER_ASSIGNED_LABEL\") | .id")

  if [[ -z "$label_id" ]]; then
    label_id=$(cmd_create_label "$USER_ASSIGNED_LABEL" "#f44336" | jq -r '.id')
  fi

  cmd_add_label_to_task "$task_id" "$label_id"
  echo "Task $task_id assigned to user"
}

# Help text
show_help() {
  cat <<EOF
Vikunja CLI - Task management for Claude Code

Usage: vikunja-cli <command> [args...]

Authentication:
  login <username> <password>     Login and save API token

Projects:
  list-projects                   List all projects
  get-project <id>                Get project details

Tasks:
  list-tasks [project_id]         List tasks (all or for specific project)
  get-task <id>                   Get task details
  create-task <project_id> <title> [description]
                                  Create a new task
  update-task <id> <key=value>... Update task fields
  complete-task <id>              Mark task as complete

Comments:
  add-comment <task_id> <text>    Add comment to task
  get-comments <task_id>          Get all comments for task

Labels:
  list-labels                     List all labels
  create-label <title> [color]    Create a new label
  add-label <task_id> <label_id>  Add label to task

Claude Code Integration:
  get-standing-instructions       Get all standing instructions for Claude
  create-standing-instruction <project_id> <title> <instruction>
                                  Create a new standing instruction
  list-user-tasks                 List tasks assigned to user
  assign-to-user <task_id>        Assign task to user for review

Environment Variables:
  VIKUNJA_URL                     Vikunja base URL (default: http://ats.local/vikunja)
  VIKUNJA_TOKEN                   API authentication token

Configuration:
  Config file: ~/.config/vikunja-cli/config
EOF
}

# Main command dispatcher
main() {
  if [[ $# -eq 0 ]]; then
    show_help
    exit 0
  fi

  local command="$1"
  shift

  case "$command" in
    login)
      cmd_login "$@"
      ;;
    list-projects)
      cmd_list_projects "$@"
      ;;
    get-project)
      cmd_get_project "$@"
      ;;
    list-tasks)
      cmd_list_tasks "$@"
      ;;
    get-task)
      cmd_get_task "$@"
      ;;
    create-task)
      cmd_create_task "$@"
      ;;
    update-task)
      cmd_update_task "$@"
      ;;
    complete-task)
      cmd_complete_task "$@"
      ;;
    add-comment)
      cmd_add_comment "$@"
      ;;
    get-comments)
      cmd_get_comments "$@"
      ;;
    list-labels)
      cmd_list_labels "$@"
      ;;
    create-label)
      cmd_create_label "$@"
      ;;
    add-label)
      cmd_add_label_to_task "$@"
      ;;
    get-standing-instructions)
      cmd_get_standing_instructions "$@"
      ;;
    create-standing-instruction)
      cmd_create_standing_instruction "$@"
      ;;
    list-user-tasks)
      cmd_list_user_tasks "$@"
      ;;
    assign-to-user)
      cmd_assign_to_user "$@"
      ;;
    help|--help|-h)
      show_help
      ;;
    *)
      echo "Unknown command: $command" >&2
      echo "Run 'vikunja-cli help' for usage information" >&2
      exit 1
      ;;
  esac
}

main "$@"
