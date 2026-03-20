#!/usr/bin/env python3  # noqa: E265
# Vikunja MCP Server
# Provides Claude Code with direct access to Vikunja task management
# via MCP protocol

import sys
import json
import subprocess
from typing import Any


def run_vikunja_cli(args: list[str]) -> dict[str, Any]:
    """Run vikunja-cli command and return parsed output"""
    try:
        result = subprocess.run(
            ["vikunja-cli"] + args,
            capture_output=True,
            text=True,
            check=True
        )

        # Try to parse as JSON, otherwise return raw text
        try:
            return {"success": True, "data": json.loads(result.stdout)}
        except json.JSONDecodeError:
            return {"success": True, "data": result.stdout.strip()}
    except subprocess.CalledProcessError as e:
        return {
            "success": False,
            "error": e.stderr.strip() if e.stderr else str(e)
        }


# MCP Tool Definitions
TOOLS = [
    {
        "name": "vikunja_list_projects",
        "description": "List all Vikunja projects",
        "inputSchema": {
            "type": "object",
            "properties": {},
            "required": []
        }
    },
    {
        "name": "vikunja_get_project",
        "description": "Get details of a specific Vikunja project",
        "inputSchema": {
            "type": "object",
            "properties": {
                "project_id": {
                    "type": "string",
                    "description": "The ID of the project to retrieve"
                }
            },
            "required": ["project_id"]
        }
    },
    {
        "name": "vikunja_list_tasks",
        "description": "List all tasks, optionally filtered by project",
        "inputSchema": {
            "type": "object",
            "properties": {
                "project_id": {
                    "type": "string",
                    "description": "Optional project ID to filter tasks"
                }
            },
            "required": []
        }
    },
    {
        "name": "vikunja_get_task",
        "description": "Get details of a specific task",
        "inputSchema": {
            "type": "object",
            "properties": {
                "task_id": {
                    "type": "string",
                    "description": "The ID of the task to retrieve"
                }
            },
            "required": ["task_id"]
        }
    },
    {
        "name": "vikunja_create_task",
        "description": "Create a new task in a project",
        "inputSchema": {
            "type": "object",
            "properties": {
                "project_id": {
                    "type": "string",
                    "description": (
                        "The ID of the project to create the task in"
                    )
                },
                "title": {
                    "type": "string",
                    "description": "The title of the task"
                },
                "description": {
                    "type": "string",
                    "description": "Optional description of the task"
                }
            },
            "required": ["project_id", "title"]
        }
    },
    {
        "name": "vikunja_complete_task",
        "description": "Mark a task as complete",
        "inputSchema": {
            "type": "object",
            "properties": {
                "task_id": {
                    "type": "string",
                    "description": "The ID of the task to complete"
                }
            },
            "required": ["task_id"]
        }
    },
    {
        "name": "vikunja_add_comment",
        "description": "Add a comment to a task",
        "inputSchema": {
            "type": "object",
            "properties": {
                "task_id": {
                    "type": "string",
                    "description": "The ID of the task to comment on"
                },
                "comment": {
                    "type": "string",
                    "description": "The comment text"
                }
            },
            "required": ["task_id", "comment"]
        }
    },
    {
        "name": "vikunja_get_comments",
        "description": "Get all comments for a task",
        "inputSchema": {
            "type": "object",
            "properties": {
                "task_id": {
                    "type": "string",
                    "description": "The ID of the task to get comments for"
                }
            },
            "required": ["task_id"]
        }
    },
    {
        "name": "vikunja_get_standing_instructions",
        "description": (
            "Get all standing instructions that Claude should keep in mind"
        ),
        "inputSchema": {
            "type": "object",
            "properties": {},
            "required": []
        }
    },
    {
        "name": "vikunja_create_standing_instruction",
        "description": (
            "Create a new standing instruction for Claude to always follow"
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "project_id": {
                    "type": "string",
                    "description": (
                        "The project ID to create the instruction in"
                    )
                },
                "title": {
                    "type": "string",
                    "description": "The title of the standing instruction"
                },
                "instruction": {
                    "type": "string",
                    "description": (
                        "The instruction text that Claude should follow"
                    )
                }
            },
            "required": ["project_id", "title", "instruction"]
        }
    },
    {
        "name": "vikunja_list_user_tasks",
        "description": (
            "List all tasks assigned to the user for review or action"
        ),
        "inputSchema": {
            "type": "object",
            "properties": {},
            "required": []
        }
    },
    {
        "name": "vikunja_assign_to_user",
        "description": "Assign a task to the user for review or clarification",
        "inputSchema": {
            "type": "object",
            "properties": {
                "task_id": {
                    "type": "string",
                    "description": "The ID of the task to assign to the user"
                }
            },
            "required": ["task_id"]
        }
    }
]


def handle_tool_call(tool_name: str, arguments: dict[str, Any]):

    """Handle a tool call from Claude Code"""

    if tool_name == "vikunja_list_projects":
        return run_vikunja_cli(["list-projects"])

    elif tool_name == "vikunja_get_project":
        return run_vikunja_cli(["get-project", arguments["project_id"]])

    elif tool_name == "vikunja_list_tasks":
        args = ["list-tasks"]
        if "project_id" in arguments:
            args.append(arguments["project_id"])
        return run_vikunja_cli(args)

    elif tool_name == "vikunja_get_task":
        return run_vikunja_cli(["get-task", arguments["task_id"]])

    elif tool_name == "vikunja_create_task":
        args = ["create-task", arguments["project_id"], arguments["title"]]
        if "description" in arguments:
            args.append(arguments["description"])
        return run_vikunja_cli(args)

    elif tool_name == "vikunja_complete_task":
        return run_vikunja_cli(["complete-task", arguments["task_id"]])

    elif tool_name == "vikunja_add_comment":
        return run_vikunja_cli([
            "add-comment",
            arguments["task_id"],
            arguments["comment"]
        ])

    elif tool_name == "vikunja_get_comments":
        return run_vikunja_cli(["get-comments", arguments["task_id"]])

    elif tool_name == "vikunja_get_standing_instructions":
        return run_vikunja_cli(["get-standing-instructions"])

    elif tool_name == "vikunja_create_standing_instruction":
        return run_vikunja_cli([
            "create-standing-instruction",
            arguments["project_id"],
            arguments["title"],
            arguments["instruction"]
        ])

    elif tool_name == "vikunja_list_user_tasks":
        return run_vikunja_cli(["list-user-tasks"])

    elif tool_name == "vikunja_assign_to_user":
        return run_vikunja_cli(["assign-to-user", arguments["task_id"]])

    else:
        return {"success": False, "error": f"Unknown tool: {tool_name}"}


def handle_request(request: dict[str, Any]) -> dict[str, Any]:
    """Handle an MCP request"""
    method = request.get("method")

    if method == "tools/list":
        return {
            "tools": TOOLS
        }

    elif method == "tools/call":
        params = request.get("params", {})
        tool_name = params.get("name")
        arguments = params.get("arguments", {})

        result = handle_tool_call(tool_name, arguments)

        return {
            "content": [
                {
                    "type": "text",
                    "text": json.dumps(result, indent=2)
                }
            ]
        }

    else:
        return {"error": f"Unknown method: {method}"}


def main():
    """Main MCP server loop"""
    # Read MCP protocol messages from stdin
    for line in sys.stdin:
        try:
            request = json.loads(line)
            response = handle_request(request)

            # Write response to stdout
            print(json.dumps(response))
            sys.stdout.flush()

        except json.JSONDecodeError:
            print(json.dumps({"error": "Invalid JSON"}), file=sys.stderr)
        except Exception as e:
            print(json.dumps({"error": str(e)}), file=sys.stderr)


if __name__ == "__main__":
    main()
