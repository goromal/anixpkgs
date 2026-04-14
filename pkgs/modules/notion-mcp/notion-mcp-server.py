#!/usr/bin/env python3  # noqa: E265
# Notion MCP Server
# Provides Claude Code with direct access to Notion pages via MCP protocol
# for the ITNS page-sorting workflow and general Notion interaction.

import sys
import json
import os
import time
import urllib.request
import urllib.error
from typing import Any


class NotionClient:
    """Client for Notion REST API"""

    API_VERSION = "2022-06-28"
    BASE_URL = "https://api.notion.com/v1"

    def __init__(self, token: str):
        self.headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Notion-Version": self.API_VERSION,
        }

    def _request(self, method: str, endpoint: str, data: dict = None) -> dict:
        url = f"{self.BASE_URL}{endpoint}"
        body = json.dumps(data).encode("utf-8") if data is not None else None
        req = urllib.request.Request(url, data=body, headers=self.headers, method=method)
        try:
            with urllib.request.urlopen(req) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            raw = e.read().decode("utf-8")
            try:
                msg = json.loads(raw).get("message", raw)
            except json.JSONDecodeError:
                msg = raw
            raise Exception(f"Notion API {e.code}: {msg}")
        except urllib.error.URLError as e:
            raise Exception(f"Network error: {e.reason}")

    # -------------------------------------------------------------------------
    # Block helpers
    # -------------------------------------------------------------------------

    def _get_block_children(self, page_id: str) -> list[dict]:
        """Fetch all block children across pagination."""
        all_blocks = []
        cursor = None
        while True:
            params = f"?start_cursor={cursor}" if cursor else ""
            data = self._request("GET", f"/blocks/{page_id}/children{params}")
            all_blocks.extend(data.get("results", []))
            if not data.get("has_more"):
                break
            cursor = data.get("next_cursor")
            time.sleep(0.3)
        return all_blocks

    def _rich_text_to_plain(self, rich_text: list) -> str:
        parts = []
        for rt in rich_text:
            if rt["type"] == "text":
                parts.append(rt["text"]["content"])
            else:
                parts.append(rt.get("plain_text", ""))
        return "".join(parts)

    def _safe_rich_text(self, rich_text: list) -> list:
        """Strip unsupported mention subtypes so the block can be re-appended."""
        safe = []
        for rt in rich_text:
            if rt["type"] == "text":
                safe.append(rt)
            elif rt["type"] == "mention":
                mtype = rt.get("mention", {}).get("type", "")
                if mtype in ("user", "date", "page", "database", "template_mention"):
                    safe.append(rt)
                else:
                    href = rt.get("href")
                    plain = rt.get("plain_text", href or "")
                    safe.append({
                        "type": "text",
                        "text": {"content": plain, "link": {"url": href} if href else None},
                        "annotations": rt.get("annotations", {}),
                    })
            else:
                safe.append(rt)
        return safe

    # -------------------------------------------------------------------------
    # Public API
    # -------------------------------------------------------------------------

    def list_subpages(self, page_id: str) -> list[dict]:
        blocks = self._get_block_children(page_id)
        results = []
        seen = set()
        for block in blocks:
            btype = block["type"]
            if btype == "child_page":
                pid = block["id"]
                title = block.get("child_page", {}).get("title", "")
                if pid not in seen:
                    results.append({"id": pid, "title": title})
                    seen.add(pid)
            bdata = block.get(btype, {})
            for rt in bdata.get("rich_text", []):
                if rt.get("type") == "mention":
                    mention = rt.get("mention", {})
                    if mention.get("type") == "page":
                        pid = mention["page"]["id"]
                        title = rt.get("plain_text", "")
                        if pid not in seen:
                            results.append({"id": pid, "title": title})
                            seen.add(pid)
        return results

    def list_blocks(self, page_id: str, block_type: str = None) -> list[dict]:
        blocks = self._get_block_children(page_id)
        results = []
        for block in blocks:
            btype = block["type"]
            if block_type and btype != block_type:
                continue
            bdata = block.get(btype, {})
            plain = self._rich_text_to_plain(bdata.get("rich_text", []))
            results.append({"id": block["id"], "type": btype, "text": plain})
        return results

    def create_subpage(self, parent_page_id: str, title: str) -> str:
        data = {
            "parent": {"page_id": parent_page_id},
            "properties": {"title": [{"type": "text", "text": {"content": title}}]},
        }
        result = self._request("POST", "/pages", data)
        return result["id"]

    def _build_block_with_children(self, block: dict) -> dict:
        """Recursively build a block payload including any nested children."""
        btype = block["type"]
        bdata = dict(block[btype])
        if "rich_text" in bdata:
            bdata["rich_text"] = self._safe_rich_text(bdata["rich_text"])
        if block.get("has_children"):
            children = self._get_block_children(block["id"])
            bdata["children"] = [self._build_block_with_children(c) for c in children]
        return {"object": "block", "type": btype, btype: bdata}

    def move_block(self, block_id: str, dest_page_id: str) -> None:
        block = self._request("GET", f"/blocks/{block_id}")
        new_block = self._build_block_with_children(block)
        self._request("PATCH", f"/blocks/{dest_page_id}/children", {"children": [new_block]})
        self._request("DELETE", f"/blocks/{block_id}")

    def append_text(self, page_id: str, text: str) -> None:
        lines = [l for l in text.split("\n") if l.strip()]
        if not lines:
            raise Exception("No content to append")
        children = [
            {
                "object": "block",
                "type": "bulleted_list_item",
                "bulleted_list_item": {
                    "rich_text": [{"type": "text", "text": {"content": line}}]
                },
            }
            for line in lines
        ]
        self._request("PATCH", f"/blocks/{page_id}/children", {"children": children})


# ---------------------------------------------------------------------------
# MCP Tool Definitions
# ---------------------------------------------------------------------------

TOOLS = [
    {
        "name": "notion_list_subpages",
        "description": (
            "List all sub-pages referenced from a Notion page, including both "
            "child_page blocks and page-mention links in rich text. Returns each "
            "sub-page's id and title. Use this to discover where blocks can be moved."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "page_id": {
                    "type": "string",
                    "description": "The Notion page ID to inspect",
                }
            },
            "required": ["page_id"],
        },
    },
    {
        "name": "notion_list_blocks",
        "description": (
            "List the top-level blocks on a Notion page as a flat array of "
            "{id, type, text}. Optionally filter by block type (e.g. "
            "'bulleted_list_item'). Use this to read the bullet points you want to sort."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "page_id": {
                    "type": "string",
                    "description": "The Notion page ID to list blocks from",
                },
                "block_type": {
                    "type": "string",
                    "description": (
                        "Optional block type filter, e.g. 'bulleted_list_item', "
                        "'paragraph', 'heading_1'"
                    ),
                },
            },
            "required": ["page_id"],
        },
    },
    {
        "name": "notion_create_subpage",
        "description": (
            "Create a new child page under a parent Notion page. Returns the new "
            "page's id. Use this when sorting reveals that a new sub-page category "
            "is needed."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "parent_page_id": {
                    "type": "string",
                    "description": "The Notion page ID to create the child under",
                },
                "title": {
                    "type": "string",
                    "description": "Title for the new child page",
                },
            },
            "required": ["parent_page_id", "title"],
        },
    },
    {
        "name": "notion_move_block",
        "description": (
            "Move a block from its current page to a destination page. Handles "
            "unsupported rich-text mention types (e.g. link embeds) by converting "
            "them to plain text links. Use this to execute approved sort moves."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "block_id": {
                    "type": "string",
                    "description": "The block ID to move",
                },
                "dest_page_id": {
                    "type": "string",
                    "description": "The destination page ID",
                },
            },
            "required": ["block_id", "dest_page_id"],
        },
    },
    {
        "name": "notion_append",
        "description": (
            "Append one or more lines of text as bulleted list items to a Notion page. "
            "Newlines in the text create separate bullets."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "page_id": {
                    "type": "string",
                    "description": "The Notion page ID to append to",
                },
                "text": {
                    "type": "string",
                    "description": "Text to append (newlines create separate bullets)",
                },
            },
            "required": ["page_id", "text"],
        },
    },
]


# ---------------------------------------------------------------------------
# Request handling
# ---------------------------------------------------------------------------

def handle_tool_call(client: NotionClient, tool_name: str, arguments: dict[str, Any]):
    try:
        if tool_name == "notion_list_subpages":
            data = client.list_subpages(arguments["page_id"])
            return {"success": True, "data": data}

        elif tool_name == "notion_list_blocks":
            data = client.list_blocks(
                arguments["page_id"], arguments.get("block_type")
            )
            return {"success": True, "data": data}

        elif tool_name == "notion_create_subpage":
            new_id = client.create_subpage(
                arguments["parent_page_id"], arguments["title"]
            )
            return {"success": True, "id": new_id}

        elif tool_name == "notion_move_block":
            client.move_block(arguments["block_id"], arguments["dest_page_id"])
            return {"success": True}

        elif tool_name == "notion_append":
            client.append_text(arguments["page_id"], arguments["text"])
            return {"success": True}

        else:
            return {"success": False, "error": f"Unknown tool: {tool_name}"}

    except Exception as e:
        print(f"Error in {tool_name}: {type(e).__name__}: {e}", file=sys.stderr)
        return {"success": False, "error": str(e)}


def handle_request(client: NotionClient, request: dict[str, Any]) -> dict[str, Any] | None:
    method = request.get("method")

    if method == "initialize":
        return {
            "protocolVersion": "2024-11-05",
            "capabilities": {"tools": {}},
            "serverInfo": {"name": "notion-mcp-server", "version": "1.0.0"},
        }

    elif method == "notifications/initialized":
        return None

    elif method == "tools/list":
        return {"tools": TOOLS}

    elif method == "tools/call":
        params = request.get("params", {})
        result = handle_tool_call(client, params.get("name"), params.get("arguments", {}))
        return {"content": [{"type": "text", "text": json.dumps(result, indent=2)}]}

    else:
        return {"error": f"Unknown method: {method}"}


def main():
    token_file = os.environ.get(
        "NOTION_TOKEN_FILE", os.path.expanduser("~/secrets/notion/secret.json")
    )
    try:
        with open(token_file) as f:
            token = json.load(f)["auth"]
    except Exception as e:
        print(
            json.dumps({"error": f"Failed to read token from {token_file}: {e}"}),
            file=sys.stderr,
        )
        sys.exit(1)

    client = NotionClient(token)

    for line in sys.stdin:
        try:
            request = json.loads(line)
            result = handle_request(client, request)
            if result is not None:
                response = {
                    "jsonrpc": "2.0",
                    "id": request.get("id"),
                    "result": result,
                }
                print(json.dumps(response))
                sys.stdout.flush()

        except json.JSONDecodeError:
            print(json.dumps({
                "jsonrpc": "2.0",
                "id": None,
                "error": {"code": -32700, "message": "Parse error"},
            }))
            sys.stdout.flush()
        except Exception as e:
            print(json.dumps({
                "jsonrpc": "2.0",
                "id": request.get("id") if "request" in locals() else None,
                "error": {"code": -32603, "message": str(e)},
            }))
            sys.stdout.flush()


if __name__ == "__main__":
    main()
