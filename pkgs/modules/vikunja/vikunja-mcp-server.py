#!/usr/bin/env python3  # noqa: E265
# Vikunja MCP Server
# Provides Claude Code with direct access to Vikunja task management
# via MCP protocol

import sys
import json
import os
import urllib.request
import urllib.error
import time
from typing import Any
import ssl

PAGE_SIZE = 100

RELATION_KINDS = [
    "subtask",
    "parenttask",
    "related",
    "duplicateof",
    "duplicates",
    "blocking",
    "blocked",
    "precedes",
    "follows",
    "copiedfrom",
    "copiedto",
]


def next_task_position() -> float:
    """Explicit position for a newly created task.

    Vikunja 2.3.0 fails the 25th task created in a project without an
    explicit position with HTTP 500 ("UNIQUE constraint failed:
    task_positions.task_id, task_positions.project_view_id"), and every
    later default-position insert in that project fails the same way.
    An explicit, monotonically increasing position avoids that path and
    keeps newly created tasks ordered by creation time.
    """
    return float(time.time_ns() // 1000)


def summarize_project(project: dict) -> dict:
    return {
        "id": project.get("id"),
        "title": project.get("title"),
        "description": project.get("description"),
        "parent_project_id": project.get("parent_project_id"),
        "is_archived": project.get("is_archived"),
    }


def summarize_task(task: dict) -> dict:
    related = task.get("related_tasks") or {}
    return {
        "id": task.get("id"),
        "title": task.get("title"),
        "done": task.get("done"),
        "priority": task.get("priority"),
        "due_date": task.get("due_date"),
        "project_id": task.get("project_id"),
        "related_task_ids": {
            kind: [t.get("id") for t in tasks]
            for kind, tasks in related.items()
            if tasks
        },
    }


class VikunjaClient:
    """Client for Vikunja REST API"""

    def __init__(self, base_url: str, api_token: str):
        self.base_url = base_url.rstrip("/")
        self.api_token = api_token
        insecure = os.environ.get("VIKUNJA_INSECURE", "").lower() in ("1", "true", "yes")
        if insecure:
            self.ssl_context = ssl.create_default_context()
            self.ssl_context.check_hostname = False
            self.ssl_context.verify_mode = ssl.CERT_NONE
        else:
            self.ssl_context = None

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
                body = response.read().decode("utf-8")
                return json.loads(body) if body else {}
        except urllib.error.HTTPError as e:
            error_body = e.read().decode("utf-8")
            try:
                error_data = json.loads(error_body)
                raise Exception(
                    f"API Error {e.code}: {error_data.get('message', error_body)}"
                )
            except json.JSONDecodeError:
                raise Exception(f"API Error {e.code}: {error_body}")
        except urllib.error.URLError as e:
            raise Exception(f"Network error connecting to {url}: {e.reason}")

    def _request_all_pages(self, endpoint: str) -> list[dict]:
        """GET every page of a list endpoint (Vikunja defaults to 50 items)"""
        items = []
        page = 1
        separator = "&" if "?" in endpoint else "?"
        while True:
            batch = self._request(
                "GET",
                f"{endpoint}{separator}page={page}&per_page={PAGE_SIZE}",
            )
            items.extend(batch or [])
            if not batch or len(batch) < PAGE_SIZE:
                return items
            page += 1

    def list_projects(self) -> list[dict]:
        """List all projects"""
        return self._request_all_pages("/api/v1/projects")

    def get_project(self, project_id: str) -> dict:
        """Get a specific project"""
        return self._request("GET", f"/api/v1/projects/{project_id}")

    def list_tasks(self, project_id: str = None) -> list[dict]:
        """List tasks, optionally filtered by project"""
        if project_id:
            return self._request_all_pages(f"/api/v1/projects/{project_id}/tasks")
        else:
            return self._request_all_pages("/api/v1/tasks/all")

    def get_task(self, task_id: str) -> dict:
        """Get a specific task"""
        return self._request("GET", f"/api/v1/tasks/{task_id}")

    def create_project(
        self, title: str, description: str = "", parent_project_id: str = None
    ) -> dict:
        """Create a new project, optionally nested under a parent project"""
        data = {"title": title, "description": description}
        if parent_project_id:
            data["parent_project_id"] = int(parent_project_id)
        return self._request("PUT", "/api/v1/projects", data)

    def create_task(
        self,
        project_id: str,
        title: str,
        description: str = "",
        priority: int = None,
        due_date: str = None,
        parent_task_id: str = None,
    ) -> dict:
        """Create a new task, optionally as a subtask of an existing task"""
        data = {
            "title": title,
            "description": description,
            "position": next_task_position(),
        }
        if priority is not None:
            data["priority"] = priority
        if due_date:
            data["due_date"] = due_date
        task = self._request(
            "PUT", f"/api/v1/projects/{project_id}/tasks", data
        )
        if parent_task_id:
            self.add_task_relation(parent_task_id, task["id"], "subtask")
        return task

    def create_task_tree(
        self, project_id: str, tasks: list[dict], parent_task_id: str = None
    ) -> list[dict]:
        """Create tasks with nested subtasks, depth first, in list order"""
        created = []
        for spec in tasks:
            task = self.create_task(
                project_id,
                spec["title"],
                spec.get("description", ""),
                spec.get("priority"),
                spec.get("due_date"),
                parent_task_id,
            )
            created.append(
                {
                    "id": task["id"],
                    "title": task["title"],
                    "subtasks": self.create_task_tree(
                        project_id, spec.get("subtasks", []), task["id"]
                    ),
                }
            )
        return created

    def add_task_relation(
        self, task_id: str, other_task_id: str, relation_kind: str
    ) -> dict:
        """Relate two tasks; Vikunja creates the inverse relation itself"""
        data = {"other_task_id": int(other_task_id), "relation_kind": relation_kind}
        return self._request("PUT", f"/api/v1/tasks/{task_id}/relations", data)

    def delete_task_relation(
        self, task_id: str, other_task_id: str, relation_kind: str
    ) -> dict:
        """Remove a relation between two tasks"""
        return self._request(
            "DELETE",
            f"/api/v1/tasks/{task_id}/relations/{relation_kind}/{other_task_id}",
        )

    def delete_task(self, task_id: str) -> dict:
        """Permanently delete a task"""
        return self._request("DELETE", f"/api/v1/tasks/{task_id}")

    def update_task(self, task_id: str, updates: dict) -> dict:
        """Update only the given fields of a task.

        Vikunja's task update replaces the whole task, so a partial body
        (e.g. just {"done": true}) clears the description and priority.
        Merge the updates onto the current task before sending it back.
        """
        task = self.get_task(task_id)
        task.update(updates)
        return self._request("POST", f"/api/v1/tasks/{task_id}", task)

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
        "description": (
            "List all Vikunja projects (id, title, description, parent, "
            "archived); pass compact=false for full project records"
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "compact": {
                    "type": "boolean",
                    "description": "Return summaries only (default true)",
                }
            },
            "required": [],
        },
    },
    {
        "name": "vikunja_create_project",
        "description": "Create a new project, optionally nested under a parent project",
        "inputSchema": {
            "type": "object",
            "properties": {
                "title": {"type": "string", "description": "Project title"},
                "description": {
                    "type": "string",
                    "description": "Optional project description (HTML allowed)",
                },
                "parent_project_id": {
                    "type": "string",
                    "description": "Optional ID of the parent project",
                },
            },
            "required": ["title"],
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
        "description": (
            "List all tasks (every page), optionally filtered by project; "
            "summaries include related task IDs such as subtask/parenttask. "
            "Pass compact=false for full task records"
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "project_id": {
                    "type": "string",
                    "description": "Optional project ID to filter tasks",
                },
                "compact": {
                    "type": "boolean",
                    "description": "Return summaries only (default true)",
                },
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
                    "description": "Optional description of the task (HTML allowed)",
                },
                "priority": {
                    "type": "integer",
                    "description": "Optional priority, 1 (low) to 5 (do now)",
                },
                "due_date": {
                    "type": "string",
                    "description": "Optional RFC 3339 due date",
                },
                "parent_task_id": {
                    "type": "string",
                    "description": "Optional ID of a task to make this a subtask of",
                },
            },
            "required": ["project_id", "title"],
        },
    },
    {
        "name": "vikunja_create_tasks",
        "description": (
            "Create several tasks in one call, each optionally with nested "
            "subtasks. Returns the created IDs as a tree"
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "project_id": {
                    "type": "string",
                    "description": "The ID of the project to create the tasks in",
                },
                "parent_task_id": {
                    "type": "string",
                    "description": "Optional ID of a task to attach the top-level tasks to",
                },
                "tasks": {
                    "type": "array",
                    "description": (
                        "Tasks: {title, description?, priority?, due_date?, "
                        "subtasks?: [same shape]}"
                    ),
                    "items": {"type": "object"},
                },
            },
            "required": ["project_id", "tasks"],
        },
    },
    {
        "name": "vikunja_add_task_relation",
        "description": (
            "Relate two tasks. relation_kind 'subtask' makes other_task_id a "
            "subtask of task_id; 'precedes'/'blocking' express ordering"
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "task_id": {"type": "string", "description": "The source task ID"},
                "other_task_id": {
                    "type": "string",
                    "description": "The related task ID",
                },
                "relation_kind": {"type": "string", "enum": RELATION_KINDS},
            },
            "required": ["task_id", "other_task_id", "relation_kind"],
        },
    },
    {
        "name": "vikunja_delete_task_relation",
        "description": "Remove a relation between two tasks",
        "inputSchema": {
            "type": "object",
            "properties": {
                "task_id": {"type": "string", "description": "The source task ID"},
                "other_task_id": {
                    "type": "string",
                    "description": "The related task ID",
                },
                "relation_kind": {"type": "string", "enum": RELATION_KINDS},
            },
            "required": ["task_id", "other_task_id", "relation_kind"],
        },
    },
    {
        "name": "vikunja_delete_task",
        "description": "Permanently delete a task",
        "inputSchema": {
            "type": "object",
            "properties": {
                "task_id": {
                    "type": "string",
                    "description": "The ID of the task to delete",
                }
            },
            "required": ["task_id"],
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
            if arguments.get("compact", True):
                data = [summarize_project(p) for p in data]
            return {"success": True, "data": data}

        elif tool_name == "vikunja_create_project":
            data = client.create_project(
                arguments["title"],
                arguments.get("description", ""),
                arguments.get("parent_project_id"),
            )
            return {"success": True, "data": summarize_project(data)}

        elif tool_name == "vikunja_get_project":
            data = client.get_project(arguments["project_id"])
            return {"success": True, "data": data}

        elif tool_name == "vikunja_list_tasks":
            project_id = arguments.get("project_id")
            data = client.list_tasks(project_id)
            if arguments.get("compact", True):
                data = [summarize_task(t) for t in data]
            return {"success": True, "data": data}

        elif tool_name == "vikunja_get_task":
            data = client.get_task(arguments["task_id"])
            return {"success": True, "data": data}

        elif tool_name == "vikunja_create_task":
            data = client.create_task(
                arguments["project_id"],
                arguments["title"],
                arguments.get("description", ""),
                arguments.get("priority"),
                arguments.get("due_date"),
                arguments.get("parent_task_id"),
            )
            return {"success": True, "data": data}

        elif tool_name == "vikunja_create_tasks":
            data = client.create_task_tree(
                arguments["project_id"],
                arguments["tasks"],
                arguments.get("parent_task_id"),
            )
            return {"success": True, "data": data}

        elif tool_name == "vikunja_add_task_relation":
            data = client.add_task_relation(
                arguments["task_id"],
                arguments["other_task_id"],
                arguments["relation_kind"],
            )
            return {"success": True, "data": data}

        elif tool_name == "vikunja_delete_task_relation":
            data = client.delete_task_relation(
                arguments["task_id"],
                arguments["other_task_id"],
                arguments["relation_kind"],
            )
            return {"success": True, "data": data}

        elif tool_name == "vikunja_delete_task":
            data = client.delete_task(arguments["task_id"])
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
        print(f"Error in {tool_name}: {type(e).__name__}: {e}", file=sys.stderr)
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
            "serverInfo": {"name": "vikunja-mcp-server", "version": "1.1.0"},
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
        token_file = os.environ.get("VIKUNJA_TOKEN_FILE")
        if token_file:
            try:
                with open(os.path.expanduser(token_file)) as f:
                    api_token = json.load(f).get("token")
            except (OSError, json.JSONDecodeError) as e:
                print(
                    json.dumps(
                        {"error": f"Failed to read token from {token_file}: {e}"}
                    ),
                    file=sys.stderr,
                )
                sys.exit(1)

    if not api_token:
        print(
            json.dumps(
                {"error": "VIKUNJA_API_TOKEN or VIKUNJA_TOKEN_FILE must be set"}
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
