#!/usr/bin/env python3  # noqa: E265
# Vikunja MCP Server
# Provides Claude Code with direct access to Vikunja task management
# via MCP protocol

import sys
import json
import os
import urllib.request
import urllib.error
from typing import Any
import ssl


class VikunjaClient:
    """Client for Vikunja REST API"""

    def __init__(self, base_url: str, api_token: str):
        self.base_url = base_url.rstrip("/")
        self.api_token = api_token
        # Create SSL context that doesn't verify certificates (for self-signed)
        self.ssl_context = ssl.create_default_context()
        self.ssl_context.check_hostname = False
        self.ssl_context.verify_mode = ssl.CERT_NONE

    def _request(
        self, method: str, endpoint: str, data: dict = None
    ) -> dict[str, Any]:
        """Make an authenticated request to Vikunja API"""
        url = f"{self.base_url}{endpoint}"
        headers = {
            "Authorization": f"Bearer {self.api_token}",
            "Content-Type": "application/json",
        }

        req_data = json.dumps(data).encode("utf-8") if data else None
        request = urllib.request.Request(
            url, data=req_data, headers=headers, method=method
        )

        try:
            with urllib.request.urlopen(
                request, context=self.ssl_context
            ) as response:
                return json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            error_body = e.read().decode("utf-8")
            try:
                error_data = json.loads(error_body)
                raise Exception(
                    f"API Error {e.code}: {error_data.get('message', error_body)}"
                )
            except json.JSONDecodeError:
                raise Exception(f"API Error {e.code}: {error_body}")

    def list_projects(self) -> list[dict]:
        """List all projects"""
        return self._request("GET", "/api/v1/projects")

    def get_project(self, project_id: str) -> dict:
        """Get a specific project"""
        return self._request("GET", f"/api/v1/projects/{project_id}")

    def list_tasks(self, project_id: str = None) -> list[dict]:
        """List tasks, optionally filtered by project"""
        if project_id:
            return self._request("GET", f"/api/v1/projects/{project_id}/tasks")
        else:
            return self._request("GET", "/api/v1/tasks/all")

    def get_task(self, task_id: str) -> dict:
        """Get a specific task"""
        return self._request("GET", f"/api/v1/tasks/{task_id}")

    def create_task(
        self, project_id: str, title: str, description: str = ""
    ) -> dict:
        """Create a new task"""
        data = {"title": title, "description": description}
        return self._request(
            "PUT", f"/api/v1/projects/{project_id}/tasks", data
        )

    def update_task(self, task_id: str, updates: dict) -> dict:
        """Update a task"""
        return self._request("POST", f"/api/v1/tasks/{task_id}", updates)

    def complete_task(self, task_id: str) -> dict:
        """Mark a task as complete"""
        return self.update_task(task_id, {"done": True})

    def add_comment(self, task_id: str, comment: str) -> dict:
        """Add a comment to a task"""
        data = {"comment": comment}
        return self._request(
            "PUT", f"/api/v1/tasks/{task_id}/comments", data
        )

    def get_comments(self, task_id: str) -> list[dict]:
        """Get all comments for a task"""
        return self._request("GET", f"/api/v1/tasks/{task_id}/comments")


# MCP Tool Definitions
TOOLS = [
    {
        "name": "vikunja_list_projects",
        "description": "List all Vikunja projects",
        "inputSchema": {
            "type": "object",
            "properties": {},
            "required": [],
        },
    },
    {
        "name": "vikunja_get_project",
        "description": "Get details of a specific Vikunja project",
        "inputSchema": {
            "type": "object",
            "properties": {
                "project_id": {
                    "type": "string",
                    "description": "The ID of the project to retrieve",
                }
            },
            "required": ["project_id"],
        },
    },
    {
        "name": "vikunja_list_tasks",
        "description": "List all tasks, optionally filtered by project",
        "inputSchema": {
            "type": "object",
            "properties": {
                "project_id": {
                    "type": "string",
                    "description": "Optional project ID to filter tasks",
                }
            },
            "required": [],
        },
    },
    {
        "name": "vikunja_get_task",
        "description": "Get details of a specific task",
        "inputSchema": {
            "type": "object",
            "properties": {
                "task_id": {
                    "type": "string",
                    "description": "The ID of the task to retrieve",
                }
            },
            "required": ["task_id"],
        },
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
                    ),
                },
                "title": {
                    "type": "string",
                    "description": "The title of the task",
                },
                "description": {
                    "type": "string",
                    "description": "Optional description of the task",
                },
            },
            "required": ["project_id", "title"],
        },
    },
    {
        "name": "vikunja_update_task",
        "description": "Update an existing task",
        "inputSchema": {
            "type": "object",
            "properties": {
                "task_id": {
                    "type": "string",
                    "description": "The ID of the task to update",
                },
                "updates": {
                    "type": "object",
                    "description": "Fields to update (e.g., title, description, done, priority)",
                },
            },
            "required": ["task_id", "updates"],
        },
    },
    {
        "name": "vikunja_complete_task",
        "description": "Mark a task as complete",
        "inputSchema": {
            "type": "object",
            "properties": {
                "task_id": {
                    "type": "string",
                    "description": "The ID of the task to complete",
                }
            },
            "required": ["task_id"],
        },
    },
    {
        "name": "vikunja_add_comment",
        "description": "Add a comment to a task",
        "inputSchema": {
            "type": "object",
            "properties": {
                "task_id": {
                    "type": "string",
                    "description": "The ID of the task to comment on",
                },
                "comment": {
                    "type": "string",
                    "description": "The comment text",
                },
            },
            "required": ["task_id", "comment"],
        },
    },
    {
        "name": "vikunja_get_comments",
        "description": "Get all comments for a task",
        "inputSchema": {
            "type": "object",
            "properties": {
                "task_id": {
                    "type": "string",
                    "description": "The ID of the task to get comments for",
                }
            },
            "required": ["task_id"],
        },
    },
]


def handle_tool_call(
    client: VikunjaClient, tool_name: str, arguments: dict[str, Any]
):
    """Handle a tool call from Claude Code"""

    try:
        if tool_name == "vikunja_list_projects":
            data = client.list_projects()
            return {"success": True, "data": data}

        elif tool_name == "vikunja_get_project":
            data = client.get_project(arguments["project_id"])
            return {"success": True, "data": data}

        elif tool_name == "vikunja_list_tasks":
            project_id = arguments.get("project_id")
            data = client.list_tasks(project_id)
            return {"success": True, "data": data}

        elif tool_name == "vikunja_get_task":
            data = client.get_task(arguments["task_id"])
            return {"success": True, "data": data}

        elif tool_name == "vikunja_create_task":
            data = client.create_task(
                arguments["project_id"],
                arguments["title"],
                arguments.get("description", ""),
            )
            return {"success": True, "data": data}

        elif tool_name == "vikunja_update_task":
            data = client.update_task(
                arguments["task_id"], arguments["updates"]
            )
            return {"success": True, "data": data}

        elif tool_name == "vikunja_complete_task":
            data = client.complete_task(arguments["task_id"])
            return {"success": True, "data": data}

        elif tool_name == "vikunja_add_comment":
            data = client.add_comment(
                arguments["task_id"], arguments["comment"]
            )
            return {"success": True, "data": data}

        elif tool_name == "vikunja_get_comments":
            data = client.get_comments(arguments["task_id"])
            return {"success": True, "data": data}

        else:
            return {"success": False, "error": f"Unknown tool: {tool_name}"}

    except Exception as e:
        return {"success": False, "error": str(e)}


def handle_request(
    client: VikunjaClient, request: dict[str, Any]
) -> dict[str, Any] | None:
    """Handle an MCP request"""
    method = request.get("method")

    if method == "initialize":
        return {
            "protocolVersion": "2024-11-05",
            "capabilities": {"tools": {}},
            "serverInfo": {"name": "vikunja-mcp-server", "version": "1.0.0"},
        }

    elif method == "notifications/initialized":
        # Notification - no response needed
        return None

    elif method == "tools/list":
        return {"tools": TOOLS}

    elif method == "tools/call":
        params = request.get("params", {})
        tool_name = params.get("name")
        arguments = params.get("arguments", {})

        result = handle_tool_call(client, tool_name, arguments)

        return {
            "content": [
                {"type": "text", "text": json.dumps(result, indent=2)}
            ]
        }

    else:
        return {"error": f"Unknown method: {method}"}


def main():
    """Main MCP server loop"""
    # Read configuration from environment
    base_url = os.environ.get("VIKUNJA_URL", "https://localhost:3457")
    api_token = os.environ.get("VIKUNJA_API_TOKEN")

    if not api_token:
        print(
            json.dumps(
                {"error": "VIKUNJA_API_TOKEN environment variable not set"}
            ),
            file=sys.stderr,
        )
        sys.exit(1)

    client = VikunjaClient(base_url, api_token)

    # Read MCP protocol messages from stdin
    for line in sys.stdin:
        try:
            request = json.loads(line)
            result = handle_request(client, request)

            # Write response to stdout (JSON-RPC format)
            if result is not None:
                response = {
                    "jsonrpc": "2.0",
                    "id": request.get("id"),
                    "result": result,
                }
                print(json.dumps(response))
                sys.stdout.flush()

        except json.JSONDecodeError:
            error_response = {
                "jsonrpc": "2.0",
                "id": request.get("id") if "request" in locals() else None,
                "error": {"code": -32700, "message": "Parse error"},
            }
            print(json.dumps(error_response))
            sys.stdout.flush()
        except Exception as e:
            error_response = {
                "jsonrpc": "2.0",
                "id": request.get("id") if "request" in locals() else None,
                "error": {"code": -32603, "message": str(e)},
            }
            print(json.dumps(error_response))
            sys.stdout.flush()


if __name__ == "__main__":
    main()
