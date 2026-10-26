import importlib.util
import json
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).with_name("notion-mcp-server.py")
SPEC = importlib.util.spec_from_file_location("notion_mcp_server", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def text_block(block_id, text, *, btype="paragraph", has_children=False, icon=None):
    return {
        "id": block_id,
        "type": btype,
        "has_children": has_children,
        btype: {
            "rich_text": [
                {
                    "type": "text",
                    "text": {"content": text, "link": None},
                    "annotations": {"bold": text.startswith("!")},
                    "plain_text": text,
                    "href": None,
                }
            ],
            "color": "default",
            "icon": icon,
        },
    }


class FakeNotionClient(MODULE.NotionClient):
    """In-memory Notion that enforces the append nesting and size limits."""

    def __init__(self, blocks=None, children=None, fail_patch=None):
        self.blocks = dict(blocks or {})
        self.children = {key: list(value) for key, value in (children or {}).items()}
        for siblings in self.children.values():
            for block in siblings:
                self.blocks.setdefault(block["id"], block)
        self.archived = set()
        self.calls = []
        self.fail_patch = fail_patch
        self.next_id = 0

    def _get_block_children(self, page_id):
        return [
            self.blocks[block["id"]]
            for block in self.children.get(page_id, [])
            if block["id"] not in self.archived
        ]

    def _validate(self, children, path, depth):
        if len(children) > 100:
            raise Exception(f"Notion API 400: {path} exceeds 100 blocks")
        for index, payload in enumerate(children):
            btype = payload["type"]
            nested = payload[btype].get("children")
            if nested is None:
                continue
            here = f"{path}[{index}].{btype}.children"
            if depth >= 2:
                raise Exception(f"Notion API 400: {here} should be not present")
            self._validate(nested, here, depth + 1)

    def _create(self, parent_id, payload):
        self.next_id += 1
        btype = payload["type"]
        data = json.loads(json.dumps(payload[btype]))
        nested = data.pop("children", [])
        for rich_text in data.get("rich_text", []):
            if rich_text["type"] == "text":
                rich_text["plain_text"] = rich_text["text"]["content"]
        block = {"id": f"new-{self.next_id}", "type": btype, btype: data}
        self.blocks[block["id"]] = block
        self.children.setdefault(parent_id, []).append(block)
        for child in nested:
            self._create(block["id"], child)
        block["has_children"] = bool(nested)
        return block

    def _request(self, method, endpoint, data=None):
        self.calls.append((method, endpoint, data))
        block_id = endpoint.removeprefix("/blocks/").removesuffix("/children")
        if method == "GET":
            return self.blocks[block_id]
        if method == "PATCH":
            if self.fail_patch and self.fail_patch(block_id, data):
                raise Exception("Notion API 500: injected failure")
            self._validate(data["children"], "body.children", 0)
            created = [self._create(block_id, payload) for payload in data["children"]]
            if block_id in self.blocks:
                self.blocks[block_id]["has_children"] = True
            return {"results": created}
        if method == "DELETE":
            self.archived.add(block_id)
            return {}
        raise AssertionError(f"Unexpected request: {method} {endpoint}")

    def tree(self, block_id):
        block = self.blocks[block_id]
        btype = block["type"]
        return {
            "type": btype,
            "text": self._rich_text_to_plain(block[btype].get("rich_text", [])),
            "children": [
                self.tree(child["id"]) for child in self._get_block_children(block_id)
            ],
        }


def deep_chain(prefix, depth):
    """Return a bulleted chain prefix-0 > prefix-1 > ... and its children map."""
    blocks = [
        text_block(
            f"{prefix}-{level}",
            f"{prefix} level {level}",
            btype="bulleted_list_item",
            has_children=level < depth - 1,
        )
        for level in range(depth)
    ]
    children = {blocks[level]["id"]: [blocks[level + 1]] for level in range(depth - 1)}
    return blocks[0], children


def expected_chain(prefix, depth, level=0):
    return {
        "type": "bulleted_list_item",
        "text": f"{prefix} level {level}",
        "children": (
            [expected_chain(prefix, depth, level + 1)] if level < depth - 1 else []
        ),
    }


class NotionClientTests(unittest.TestCase):
    def test_recursive_listing_preserves_order_and_children(self):
        parent = text_block("parent", "Parent", has_children=True)
        child = text_block("child", "Child")
        sibling = text_block("sibling", "Sibling")
        client = FakeNotionClient(
            children={"page": [parent, sibling], "parent": [child]}
        )

        result = client.list_blocks("page", recursive=True)

        self.assertEqual([block["index"] for block in result], [0, 1])
        self.assertTrue(result[0]["has_children"])
        self.assertEqual(result[0]["children"][0]["text"], "Child")
        self.assertEqual(result[0]["children"][0]["index"], 0)
        self.assertNotIn("children", result[1])

    def test_batch_move_prunes_nulls_and_archives_after_copy(self):
        client = FakeNotionClient(
            children={
                "source": [
                    text_block("first", "First", icon=None),
                    text_block("second", "Second", icon=None),
                ]
            }
        )

        result = client.move_blocks(["first", "second"], "destination")

        self.assertEqual(
            result,
            [
                {"source_id": "first", "new_id": "new-1"},
                {"source_id": "second", "new_id": "new-2"},
            ],
        )
        patch_index = next(
            index for index, call in enumerate(client.calls) if call[0] == "PATCH"
        )
        delete_indexes = [
            index for index, call in enumerate(client.calls) if call[0] == "DELETE"
        ]
        self.assertTrue(all(patch_index < index for index in delete_indexes))
        payload = client.calls[patch_index][2]
        self.assertNotIn("icon", payload["children"][0]["paragraph"])
        self.assertNotIn(
            "link",
            payload["children"][0]["paragraph"]["rich_text"][0]["text"],
        )

    def test_batch_move_rejects_duplicate_ids_before_writing(self):
        client = FakeNotionClient({"first": text_block("first", "First")})

        with self.assertRaisesRegex(Exception, "duplicate"):
            client.move_blocks(["first", "first"], "destination")

        self.assertEqual(client.calls, [])

    def test_move_copies_tree_deeper_than_api_nesting_limit(self):
        root, children = deep_chain("school", 7)
        client = FakeNotionClient(children={"science": [root], **children})

        result = client.move_block("school-0", "abstraction")

        new_id = result["new_id"]
        self.assertEqual(client.tree(new_id), expected_chain("school", 7))
        self.assertEqual(
            [block["id"] for block in client._get_block_children("abstraction")],
            [new_id],
        )
        self.assertEqual(client._get_block_children("science"), [])
        last_patch = max(i for i, call in enumerate(client.calls) if call[0] == "PATCH")
        first_delete = min(
            i for i, call in enumerate(client.calls) if call[0] == "DELETE"
        )
        self.assertLess(last_patch, first_delete)

    def test_ordered_compound_move_with_deep_tree_and_wide_children(self):
        root, children = deep_chain("deep", 5)
        wide_parent = text_block("wide", "Wide", has_children=True)
        wide_children = [text_block(f"w{i}", f"Wide {i}") for i in range(130)]
        table = {
            "id": "table",
            "type": "table",
            "has_children": True,
            "table": {
                "table_width": 2,
                "has_column_header": True,
                "has_row_header": False,
            },
        }
        rows = [
            {
                "id": f"row{i}",
                "type": "table_row",
                "has_children": False,
                "table_row": {
                    "cells": [
                        [{"type": "text", "text": {"content": f"r{i}c{c}"}}]
                        for c in range(2)
                    ]
                },
            }
            for i in range(3)
        ]
        heading = text_block("heading", "Heading", btype="heading_2")
        client = FakeNotionClient(
            children={
                "science": [heading, root, wide_parent, table],
                "wide": wide_children,
                "table": rows,
                **children,
            }
        )

        result = client.move_blocks(
            ["heading", "deep-0", "wide", "table"], "abstraction"
        )

        new_ids = [move["new_id"] for move in result]
        self.assertEqual(
            [block["id"] for block in client._get_block_children("abstraction")],
            new_ids,
        )
        self.assertEqual(client.tree(new_ids[0])["text"], "Heading")
        self.assertEqual(client.tree(new_ids[1]), expected_chain("deep", 5))
        self.assertEqual(
            [child["text"] for child in client.tree(new_ids[2])["children"]],
            [f"Wide {i}" for i in range(130)],
        )
        new_rows = client._get_block_children(new_ids[3])
        self.assertEqual(
            [row["table_row"]["cells"][0][0]["text"]["content"] for row in new_rows],
            ["r0c0", "r1c0", "r2c0"],
        )
        self.assertEqual(client._get_block_children("science"), [])

    def test_failure_copying_descendants_rolls_back_and_keeps_sources(self):
        root, children = deep_chain("school", 6)
        sibling = text_block("sibling", "Sibling")
        client = FakeNotionClient(
            children={"science": [root, sibling], **children},
            fail_patch=lambda parent, data: (
                data["children"][0]["bulleted_list_item"]["rich_text"][0]["text"][
                    "content"
                ]
                == "school level 3"
            ),
        )

        with self.assertRaises(MODULE.MoveError) as raised:
            client.move_blocks(["school-0", "sibling"], "abstraction")

        details = raised.exception.details
        self.assertFalse(details["sources_archived"])
        self.assertEqual(details["partial_copies_rolled_back"], ["new-1", "new-2"])
        self.assertEqual(details["partial_copies_left_in_place"], [])
        self.assertEqual(client._get_block_children("abstraction"), [])
        self.assertEqual(
            [block["id"] for block in client._get_block_children("science")],
            ["school-0", "sibling"],
        )
        self.assertFalse(client.archived & {"school-0", "sibling"})

    def test_failed_tool_call_sets_mcp_error_flag(self):
        root, children = deep_chain("school", 4)
        client = FakeNotionClient(
            children={"science": [root], **children},
            fail_patch=lambda parent, data: parent != "abstraction",
        )

        response = MODULE.handle_request(
            client,
            {
                "method": "tools/call",
                "params": {
                    "name": "notion_move_block",
                    "arguments": {
                        "block_id": "school-0",
                        "dest_page_id": "abstraction",
                    },
                },
            },
        )

        self.assertTrue(response["isError"])
        payload = json.loads(response["content"][0]["text"])
        self.assertFalse(payload["success"])
        self.assertEqual(payload["details"]["partial_copies_rolled_back"], ["new-1"])

    def test_successful_tool_call_clears_mcp_error_flag(self):
        client = FakeNotionClient(children={"science": [text_block("a", "A")]})

        response = MODULE.handle_request(
            client,
            {
                "method": "tools/call",
                "params": {
                    "name": "notion_move_block",
                    "arguments": {"block_id": "a", "dest_page_id": "abstraction"},
                },
            },
        )

        self.assertFalse(response["isError"])


if __name__ == "__main__":
    unittest.main()
