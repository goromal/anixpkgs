#!/usr/bin/env python3  # noqa: E265
# Wiki MCP Server
# Provides Claude Code with direct access to DokuWiki pages via MCP protocol.

import sys
import json
import os
import re
import socket
import subprocess
import http.cookiejar
import urllib.request
import xmlrpc.client
from typing import Any


class CookieTransport(xmlrpc.client.Transport):
    """XMLRPC transport using cookie-based session auth (DokuWiki cookieAuth mode)."""

    def __init__(self):
        super().__init__()
        jar = http.cookiejar.CookieJar()
        self._opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))

    def request(self, host, handler, request_body, verbose=False):
        self.verbose = verbose
        url = f"http://{host}{handler}"
        req = urllib.request.Request(url, request_body, {"Content-Type": "text/xml"})
        resp = self._opener.open(req)
        return self.parse_response(resp)


class WikiClient:
    """Client for DokuWiki XMLRPC API using cookie-based auth."""

    def __init__(self, wiki_url: str, wiki_user: str, wiki_pass: str):
        self.wiki_url = wiki_url
        xmlrpc_url = f"{wiki_url}/lib/exe/xmlrpc.php"
        transport = CookieTransport()
        self.server = xmlrpc.client.ServerProxy(xmlrpc_url, transport=transport)
        if not self.server.dokuwiki.login(wiki_user, wiki_pass):
            raise Exception(f"DokuWiki login failed for user {wiki_user!r}")

    def get_page(self, page_id: str) -> str:
        return self.server.wiki.getPage(page_id)

    def put_page(self, page_id: str, content: str) -> None:
        self.server.wiki.putPage(page_id, content, {})


# ---------------------------------------------------------------------------
# Format conversion helpers (DokuWiki <-> Markdown)
# ---------------------------------------------------------------------------

def _apply_conversions(text: str, rules: list) -> str:
    for pattern, replacement in rules:
        text = re.sub(pattern, replacement, text, flags=re.M)
    return text


def doku_to_markdown(doku: str) -> str:
    rules = [
        (r"======\s+([^=]+)\s+======", r"# \1"),
        (r"=====\s+([^=]+)\s+=====", r"## \1"),
        (r"====\s+([^=]+)\s+====", r"### \1"),
        (r"===\s+([^=]+)\s+===", r"#### \1"),
        (r"//([^/]+)//", r"*\1*"),
        (r"\[\[(.+)\|(.*)\]\]", r"[\2](\1)"),
    ]
    return _apply_conversions(doku, rules)


def markdown_to_doku(markdown: str) -> str:
    rules = [
        (r"####\s+(.+)", r"=== \1 ==="),
        (r"###\s+(.+)", r"==== \1 ===="),
        (r"##\s+(.+)", r"===== \1 ====="),
        (r"#\s+(.+)", r"====== \1 ======"),
        (r"([^\*])\*([^\*]+)\*([^\*])", r"\1//\2//\3"),
        (r"\[(.+)\]\((.+)\)", r"[[\2|\1]]"),
    ]
    return _apply_conversions(markdown, rules)


# ---------------------------------------------------------------------------
# MCP Tool Definitions
# ---------------------------------------------------------------------------

TOOLS = [
    {
        "name": "wiki_get_page",
        "description": (
            "Read the raw DokuWiki content of a page by its page ID "
            "(e.g. 'namespace:pagename'). Returns the page content as a string."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "page_id": {
                    "type": "string",
                    "description": "The DokuWiki page ID (e.g. 'notes:2024' or 'start')",
                }
            },
            "required": ["page_id"],
        },
    },
    {
        "name": "wiki_get_page_md",
        "description": (
            "Read a DokuWiki page by its page ID and return the content "
            "converted to Markdown format."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "page_id": {
                    "type": "string",
                    "description": "The DokuWiki page ID (e.g. 'notes:2024' or 'start')",
                }
            },
            "required": ["page_id"],
        },
    },
    {
        "name": "wiki_put_page",
        "description": (
            "Write raw DokuWiki content to a page, replacing its current content. "
            "Use DokuWiki syntax (e.g. '====== Title ======' for headings)."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "page_id": {
                    "type": "string",
                    "description": "The DokuWiki page ID to write to",
                },
                "content": {
                    "type": "string",
                    "description": "Raw DokuWiki content to write",
                },
            },
            "required": ["page_id", "content"],
        },
    },
    {
        "name": "wiki_put_page_md",
        "description": (
            "Write Markdown content to a DokuWiki page, converting it to DokuWiki "
            "syntax automatically. Replaces the current page content."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "page_id": {
                    "type": "string",
                    "description": "The DokuWiki page ID to write to",
                },
                "content": {
                    "type": "string",
                    "description": "Markdown content to convert and write",
                },
            },
            "required": ["page_id", "content"],
        },
    },
]


# ---------------------------------------------------------------------------
# Request handling
# ---------------------------------------------------------------------------

def handle_tool_call(client: WikiClient, tool_name: str, arguments: dict[str, Any]):
    try:
        if tool_name == "wiki_get_page":
            content = client.get_page(arguments["page_id"])
            return {"success": True, "content": content}

        elif tool_name == "wiki_get_page_md":
            content = client.get_page(arguments["page_id"])
            return {"success": True, "content": doku_to_markdown(content)}

        elif tool_name == "wiki_put_page":
            client.put_page(arguments["page_id"], arguments["content"])
            return {"success": True}

        elif tool_name == "wiki_put_page_md":
            doku_content = markdown_to_doku(arguments["content"])
            client.put_page(arguments["page_id"], doku_content)
            return {"success": True}

        else:
            return {"success": False, "error": f"Unknown tool: {tool_name}"}

    except Exception as e:
        print(f"Error in {tool_name}: {type(e).__name__}: {e}", file=sys.stderr)
        return {"success": False, "error": str(e)}


def handle_request(client: WikiClient, request: dict[str, Any]) -> dict[str, Any] | None:
    method = request.get("method")

    if method == "initialize":
        return {
            "protocolVersion": "2024-11-05",
            "capabilities": {"tools": {}},
            "serverInfo": {"name": "wiki-mcp-server", "version": "1.0.0"},
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
    wiki_url = os.environ.get("WIKI_URL", f"http://{socket.gethostname()}.local")
    secrets_dir = os.path.expanduser(
        os.environ.get("WIKI_SECRETS_DIR", "~/secrets/wiki")
    )

    try:
        user_file = os.path.join(secrets_dir, "u.txt")
        pass_file = os.path.join(secrets_dir, "p.txt.tyz")
        with open(user_file) as f:
            wiki_user = f.read().strip()
        result = subprocess.run(
            ["sread", pass_file], capture_output=True, text=True, check=True
        )
        wiki_pass = result.stdout.strip()
    except Exception as e:
        print(
            json.dumps({"error": f"Failed to read wiki credentials from {secrets_dir}: {e}"}),
            file=sys.stderr,
        )
        sys.exit(1)

    client = WikiClient(wiki_url, wiki_user, wiki_pass)

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
