import importlib.util
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("notion-mcp-server.py")
SPEC = importlib.util.spec_from_file_location("notion_mcp_server", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def text_block(block_id, text, *, has_children=False, icon=None):
    return {
        "id": block_id,
        "type": "paragraph",
        "has_children": has_children,
        "paragraph": {
            "rich_text": [
                {
                    "type": "text",
                    "text": {"content": text, "link": None},
                    "plain_text": text,
                    "href": None,
                }
            ],
            "color": "default",
            "icon": icon,
        },
    }


class FakeNotionClient(MODULE.NotionClient):
    def __init__(self, blocks, children=None):
        self.blocks = blocks
        self.children = children or {}
        self.calls = []

    def _get_block_children(self, page_id):
        return self.children.get(page_id, [])

    def _request(self, method, endpoint, data=None):
        self.calls.append((method, endpoint, data))
        if method == "GET":
            return self.blocks[endpoint.removeprefix("/blocks/")]
        if method == "PATCH":
            return {
                "results": [
                    {"id": f"new-{index}"}
                    for index, _block in enumerate(data["children"])
                ]
            }
        if method == "DELETE":
            return {}
        raise AssertionError(f"Unexpected request: {method} {endpoint}")


class NotionClientTests(unittest.TestCase):
    def test_recursive_listing_preserves_order_and_children(self):
        parent = text_block("parent", "Parent", has_children=True)
        child = text_block("child", "Child")
        sibling = text_block("sibling", "Sibling")
        client = FakeNotionClient(
            {}, children={"page": [parent, sibling], "parent": [child]}
        )

        result = client.list_blocks("page", recursive=True)

        self.assertEqual([block["index"] for block in result], [0, 1])
        self.assertTrue(result[0]["has_children"])
        self.assertEqual(result[0]["children"][0]["text"], "Child")
        self.assertEqual(result[0]["children"][0]["index"], 0)
        self.assertNotIn("children", result[1])

    def test_batch_move_prunes_nulls_and_archives_after_copy(self):
        blocks = {
            "first": text_block("first", "First", icon=None),
            "second": text_block("second", "Second", icon=None),
        }
        client = FakeNotionClient(blocks)

        result = client.move_blocks(["first", "second"], "destination")

        self.assertEqual(
            result,
            [
                {"source_id": "first", "new_id": "new-0"},
                {"source_id": "second", "new_id": "new-1"},
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


if __name__ == "__main__":
    unittest.main()
