#!/usr/bin/env python3  # noqa: E265
# Notion MCP Server
# Provides Claude Code with direct access to Notion pages via MCP protocol
# for the ITNS page-sorting workflow and general Notion interaction.

import sys
import json
import os
import re
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

    # -------------------------------------------------------------------------
    # Markdown -> Notion blocks
    # -------------------------------------------------------------------------

    # Notion's code block accepts a fixed language enum; map common aliases and
    # fall back to "plain text" so an unknown fence never fails the whole append.
    _CODE_LANGS = {
        "bash", "c", "c++", "c#", "css", "diff", "docker", "go", "graphql",
        "html", "java", "javascript", "json", "kotlin", "makefile", "markdown",
        "nix", "plain text", "python", "ruby", "rust", "scala", "shell", "sql",
        "swift", "typescript", "xml", "yaml",
    }
    _LANG_ALIASES = {
        "": "plain text", "txt": "plain text", "text": "plain text",
        "cpp": "c++", "cs": "c#", "sh": "shell", "zsh": "shell",
        "py": "python", "rb": "ruby", "rs": "rust", "js": "javascript",
        "ts": "typescript", "yml": "yaml", "md": "markdown",
    }

    _INLINE_RE = re.compile(
        r"(?P<code>`[^`]+`)"
        r"|(?P<bold>\*\*[^*]+\*\*)"
        r"|(?P<link>\[[^\]]+\]\([^)]+\))"
        r"|(?P<italic>\*[^*]+\*)"
    )
    _HEADING_RE = re.compile(r"^(#{1,6})\s+(.*)$")
    _BULLET_RE = re.compile(r"^\s*[-*+]\s+(.*)$")
    _NUMBER_RE = re.compile(r"^\s*\d+\.\s+(.*)$")
    _QUOTE_RE = re.compile(r"^>\s?(.*)$")
    _HR_RE = re.compile(r"^\s*([-*_])\1{2,}\s*$")
    _TABLE_ROW_RE = re.compile(r"^\s*\|.+\|\s*$")

    @staticmethod
    def _chunks(s: str, n: int = 2000) -> list[str]:
        return [s[i:i + n] for i in range(0, len(s), n)] or [""]

    def _rt(self, content: str, *, bold=False, italic=False, code=False,
            link: str = None) -> list[dict]:
        ann = {}
        if bold:
            ann["bold"] = True
        if italic:
            ann["italic"] = True
        if code:
            ann["code"] = True
        items = []
        for chunk in self._chunks(content):
            text = {"content": chunk}
            if link:
                text["link"] = {"url": link}
            item = {"type": "text", "text": text}
            if ann:
                item["annotations"] = dict(ann)
            items.append(item)
        return items

    def _inline_rich_text(self, text: str) -> list[dict]:
        rich: list[dict] = []
        pos = 0
        for m in self._INLINE_RE.finditer(text):
            if m.start() > pos:
                rich += self._rt(text[pos:m.start()])
            if m.group("code"):
                rich += self._rt(m.group("code")[1:-1], code=True)
            elif m.group("bold"):
                rich += self._rt(m.group("bold")[2:-2], bold=True)
            elif m.group("italic"):
                rich += self._rt(m.group("italic")[1:-1], italic=True)
            elif m.group("link"):
                lm = re.match(r"\[([^\]]+)\]\(([^)]+)\)", m.group("link"))
                rich += self._rt(lm.group(1), link=lm.group(2))
            pos = m.end()
        if pos < len(text):
            rich += self._rt(text[pos:])
        return rich

    def _block(self, btype: str, text: str = "", extra: dict = None) -> dict:
        body = {"rich_text": self._inline_rich_text(text)}
        if extra:
            body.update(extra)
        return {"object": "block", "type": btype, btype: body}

    def _code_block(self, code: str, lang: str) -> dict:
        lang = lang.strip().lower()
        lang = self._LANG_ALIASES.get(lang, lang)
        if lang not in self._CODE_LANGS:
            lang = "plain text"
        return {
            "object": "block",
            "type": "code",
            "code": {"rich_text": self._rt(code), "language": lang},
        }

    @staticmethod
    def _is_table_sep(line: str) -> bool:
        s = line.strip().strip("|")
        cells = s.split("|")
        return bool(cells) and all(
            re.fullmatch(r"\s*:?-+:?\s*", c) for c in cells
        )

    @staticmethod
    def _split_row(line: str) -> list[str]:
        return [c.strip() for c in line.strip().strip("|").split("|")]

    def _parse_table(self, lines: list[str], i: int) -> tuple[dict, int]:
        header = self._split_row(lines[i])
        width = len(header)
        rows = [header]
        i += 2  # skip header row and separator row
        while (i < len(lines) and self._TABLE_ROW_RE.match(lines[i])
               and not self._is_table_sep(lines[i])):
            cells = (self._split_row(lines[i]) + [""] * width)[:width]
            rows.append(cells)
            i += 1
        children = [
            {
                "object": "block",
                "type": "table_row",
                "table_row": {"cells": [self._inline_rich_text(c) for c in r]},
            }
            for r in rows
        ]
        table = {
            "object": "block",
            "type": "table",
            "table": {
                "table_width": width,
                "has_column_header": True,
                "has_row_header": False,
                "children": children,
            },
        }
        return table, i

    def _markdown_to_blocks(self, md: str) -> list[dict]:
        lines = md.split("\n")
        blocks: list[dict] = []
        para: list[str] = []
        i, n = 0, len(lines)

        def flush_para():
            if para:
                blocks.append(self._block("paragraph", " ".join(para)))
                para.clear()

        while i < n:
            line = lines[i]
            stripped = line.strip()

            if stripped.startswith("```"):
                flush_para()
                lang = stripped[3:].strip()
                code_lines = []
                i += 1
                while i < n and not lines[i].strip().startswith("```"):
                    code_lines.append(lines[i])
                    i += 1
                i += 1  # skip closing fence
                blocks.append(self._code_block("\n".join(code_lines), lang))
                continue

            if (self._TABLE_ROW_RE.match(line) and i + 1 < n
                    and self._is_table_sep(lines[i + 1])):
                flush_para()
                table, i = self._parse_table(lines, i)
                blocks.append(table)
                continue

            m = self._HEADING_RE.match(line)
            if m:
                flush_para()
                level = min(len(m.group(1)), 3)
                blocks.append(self._block(f"heading_{level}", m.group(2).strip()))
                i += 1
                continue

            if self._HR_RE.match(line):
                flush_para()
                blocks.append({"object": "block", "type": "divider", "divider": {}})
                i += 1
                continue

            if stripped.startswith(">"):
                flush_para()
                quote = [self._QUOTE_RE.match(line).group(1)]
                i += 1
                while i < n and lines[i].lstrip().startswith(">"):
                    quote.append(self._QUOTE_RE.match(lines[i]).group(1))
                    i += 1
                blocks.append(self._block("quote", "\n".join(quote)))
                continue

            m = self._BULLET_RE.match(line)
            if m:
                flush_para()
                blocks.append(self._block("bulleted_list_item", m.group(1).strip()))
                i += 1
                continue

            m = self._NUMBER_RE.match(line)
            if m:
                flush_para()
                blocks.append(self._block("numbered_list_item", m.group(1).strip()))
                i += 1
                continue

            if not stripped:
                flush_para()
                i += 1
                continue

            para.append(stripped)
            i += 1

        flush_para()
        return blocks

    def _append_children(self, page_id: str, children: list[dict]) -> int:
        # Notion caps a single append at 100 blocks; chunk to stay under it.
        for j in range(0, len(children), 100):
            self._request(
                "PATCH", f"/blocks/{page_id}/children",
                {"children": children[j:j + 100]},
            )
            if j + 100 < len(children):
                time.sleep(0.3)
        return len(children)

    # -------------------------------------------------------------------------
    # Write operations
    # -------------------------------------------------------------------------

    def append_markdown(self, page_id: str, text: str) -> int:
        blocks = self._markdown_to_blocks(text)
        if not blocks:
            raise Exception("No content to append")
        return self._append_children(page_id, blocks)

    def append_bullets(self, page_id: str, text: str) -> int:
        lines = [l for l in text.split("\n") if l.strip()]
        if not lines:
            raise Exception("No content to append")
        children = [self._block("bulleted_list_item", line) for line in lines]
        return self._append_children(page_id, children)

    def delete_block(self, block_id: str) -> None:
        self._request("DELETE", f"/blocks/{block_id}")

    def update_block(self, block_id: str, text: str) -> None:
        block = self._request("GET", f"/blocks/{block_id}")
        btype = block["type"]
        if "rich_text" not in block.get(btype, {}):
            raise Exception(f"Block type '{btype}' has no editable text")
        self._request(
            "PATCH", f"/blocks/{block_id}",
            {btype: {"rich_text": self._inline_rich_text(text)}},
        )


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
            "Append Markdown to a Notion page, converted into native Notion blocks. "
            "Supports headings (#/##/###), fenced code blocks with language "
            "(```lang), tables (| a | b | with a |---| separator row), bulleted and "
            "numbered lists, blockquotes (>), dividers (---), paragraphs, and inline "
            "**bold**, *italic*, `code`, and [links](url). Blank lines separate "
            "paragraphs. Set format='bullets' to instead turn each input line into a "
            "literal bullet (legacy behavior)."
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
                    "description": "Markdown text to append (or raw lines if format='bullets')",
                },
                "format": {
                    "type": "string",
                    "enum": ["markdown", "bullets"],
                    "description": "How to interpret 'text'. Default 'markdown'.",
                },
            },
            "required": ["page_id", "text"],
        },
    },
    {
        "name": "notion_delete_block",
        "description": (
            "Delete (archive) a block by id. Notion archives the block so it can be "
            "restored from the page history. Use this to remove blocks directly "
            "instead of parking them on a scratch page."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "block_id": {
                    "type": "string",
                    "description": "The block ID to delete",
                },
            },
            "required": ["block_id"],
        },
    },
    {
        "name": "notion_update_block",
        "description": (
            "Replace the text content of an existing block in place, keeping its "
            "type. 'text' is parsed for inline **bold**, *italic*, `code`, and "
            "[links](url). Only works on text-bearing blocks (paragraph, headings, "
            "list items, quote, etc.); to change a block's type, delete and re-append."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "block_id": {
                    "type": "string",
                    "description": "The block ID to update",
                },
                "text": {
                    "type": "string",
                    "description": "New text content (inline Markdown supported)",
                },
            },
            "required": ["block_id", "text"],
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
            fmt = arguments.get("format", "markdown")
            if fmt == "bullets":
                count = client.append_bullets(arguments["page_id"], arguments["text"])
            else:
                count = client.append_markdown(arguments["page_id"], arguments["text"])
            return {"success": True, "blocks_added": count}

        elif tool_name == "notion_delete_block":
            client.delete_block(arguments["block_id"])
            return {"success": True}

        elif tool_name == "notion_update_block":
            client.update_block(arguments["block_id"], arguments["text"])
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
            "serverInfo": {"name": "notion-mcp-server", "version": "1.1.0"},
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
