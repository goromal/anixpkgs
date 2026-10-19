import json
import unittest

import google_slides_mcp_server as srv
from tests.fakes import FakeSlidesClient


class ProtocolTest(unittest.TestCase):
    def call(self, client, name, args):
        return srv.handle_request(client, {
            "jsonrpc": "2.0", "id": 7, "method": "tools/call",
            "params": {"name": name, "arguments": args}})

    def test_initialize(self):
        resp = srv.handle_request(FakeSlidesClient(),
                                  {"jsonrpc": "2.0", "id": 1, "method": "initialize"})
        self.assertEqual(resp["result"]["serverInfo"]["name"], "google-slides-mcp-server")

    def test_tools_are_unique_and_schematized(self):
        resp = srv.handle_request(FakeSlidesClient(),
                                  {"jsonrpc": "2.0", "id": 1, "method": "tools/list"})
        tools = resp["result"]["tools"]
        names = [t["name"] for t in tools]
        self.assertEqual(len(names), len(set(names)))
        self.assertGreaterEqual(len(names), 40)
        for t in tools:
            schema = t["inputSchema"]
            for req in schema["required"]:
                self.assertIn(req, schema["properties"], f"{t['name']}:{req}")

    def test_every_tool_is_dispatched(self):
        for tool in srv.TOOLS:
            result = srv.handle_tool_call(FakeSlidesClient(), tool["name"], {})
            self.assertNotIn("Unknown tool", result.get("error", ""), tool["name"])

    def test_tool_call_wraps_result(self):
        resp = self.call(FakeSlidesClient(), "slides_list_presentations", {})
        content = resp["result"]["content"]
        self.assertFalse(resp["result"]["isError"])
        self.assertEqual(json.loads(content[0]["text"])["presentations"][0]["id"], "p1")

    def test_errors_flag_is_error(self):
        resp = self.call(FakeSlidesClient(), "slides_create_slide", {})
        self.assertTrue(resp["result"]["isError"])
        self.assertIn("presentation_id", resp["result"]["content"][0]["text"])

    def test_thumbnail_returns_image_block(self):
        resp = self.call(FakeSlidesClient(), "slides_get_thumbnail",
                         {"presentation_id": "p1", "slide_id": "s1"})
        content = resp["result"]["content"]
        self.assertEqual(content[1]["type"], "image")
        self.assertEqual(content[1]["mimeType"], "image/png")
        self.assertNotIn("_image", content[0]["text"])

    def test_unknown_method(self):
        resp = srv.handle_request(FakeSlidesClient(),
                                  {"jsonrpc": "2.0", "id": 3, "method": "bogus"})
        self.assertEqual(resp["error"]["code"], -32601)


if __name__ == "__main__":
    unittest.main()
