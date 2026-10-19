import os
import tempfile
import unittest

import google_slides_mcp_server as srv
from tests.fakes import FakeSlidesClient

DECK = {
    "presentationId": "p1",
    "title": "Deck",
    "pageSize": {"width": {"magnitude": 9144000, "unit": "EMU"},
                 "height": {"magnitude": 5143500, "unit": "EMU"}},
    "layouts": [{"objectId": "L1", "layoutProperties": {"name": "TITLE", "displayName": "Title"}}],
    "slides": [{
        "objectId": "s1",
        "pageElements": [
            {"objectId": "title1",
             "size": {"width": {"magnitude": 3000000, "unit": "EMU"},
                      "height": {"magnitude": 1000000, "unit": "EMU"}},
             "transform": {"scaleX": 2, "scaleY": 1, "translateX": 127000,
                           "translateY": 254000, "unit": "EMU"},
             "shape": {"shapeType": "TEXT_BOX", "placeholder": {"type": "TITLE"},
                       "text": {"textElements": [{"textRun": {"content": "Hello\n"}}]}}},
            {"objectId": "empty1", "shape": {"shapeType": "RECTANGLE"}},
            {"objectId": "tbl", "table": {"rows": 1, "columns": 2, "tableRows": [
                {"tableCells": [
                    {"text": {"textElements": [{"textRun": {"content": "a\n"}}]}},
                    {}]}]}},
        ],
        "slideProperties": {"layoutObjectId": "L1", "notesPage": {
            "notesProperties": {"speakerNotesObjectId": "notes1"},
            "pageElements": [{"objectId": "notes1", "shape": {"text": {
                "textElements": [{"textRun": {"content": "say hi\n"}}]}}}]}},
    }],
}


class ToolTest(unittest.TestCase):
    def run_tool(self, name, client=None, **args):
        client = client or FakeSlidesClient(presentation=DECK, page=DECK["slides"][0])
        result = srv.handle_tool_call(client, name, args)
        return client, result

    def only_batch(self, client):
        self.assertEqual(len(client.batches), 1)
        return client.batches[0]

    def test_get_presentation_summary(self):
        _, r = self.run_tool("slides_get_presentation", presentation_id="p1")
        self.assertEqual(r["pageSize_pt"], {"width": 720.0, "height": 405.0})
        slide = r["slides"][0]
        title = slide["elements"][0]
        self.assertEqual(title["text"], "Hello\n")
        self.assertEqual(title["placeholder"], "TITLE")
        self.assertEqual(title["frame_pt"], {"x": 10.0, "y": 20.0,
                                             "width": 472.44, "height": 78.74})
        self.assertEqual(slide["elements"][2]["cells"], [["a\n", ""]])
        self.assertEqual(slide["speakerNotes"], "say hi\n")
        self.assertEqual(r["layouts"][0]["objectId"], "L1")

    def test_create_slide_with_placeholders(self):
        c, r = self.run_tool("slides_create_slide", presentation_id="p1",
                             layout="TITLE_AND_BODY", title="T", body="B")
        reqs = self.only_batch(c)
        create = reqs[0]["createSlide"]
        self.assertEqual(create["slideLayoutReference"], {"predefinedLayout": "TITLE_AND_BODY"})
        types = {m["layoutPlaceholder"]["type"] for m in create["placeholderIdMappings"]}
        self.assertEqual(types, {"TITLE", "BODY"})
        self.assertEqual([q["insertText"]["text"] for q in reqs[1:]], ["T", "B"])
        self.assertEqual(set(r["placeholder_ids"]), {"TITLE", "BODY"})

    def test_title_layout_uses_centered_title(self):
        c, r = self.run_tool("slides_create_slide", presentation_id="p1",
                             layout="TITLE", title="T", subtitle="S")
        self.assertEqual(set(r["placeholder_ids"]), {"CENTERED_TITLE", "SUBTITLE"})

    def test_create_slide_with_notes(self):
        c, _ = self.run_tool("slides_create_slide", presentation_id="p1",
                             speaker_notes="remember")
        self.assertEqual(c.batches[1][0]["insertText"]["objectId"], "notes1")

    def test_set_text_replaces_existing(self):
        c, _ = self.run_tool("slides_set_text", presentation_id="p1",
                             object_id="title1", text="New")
        reqs = self.only_batch(c)
        self.assertIn("deleteText", reqs[0])
        self.assertEqual(reqs[1]["insertText"]["text"], "New")

    def test_set_text_skips_delete_on_empty_shape(self):
        c, _ = self.run_tool("slides_set_text", presentation_id="p1",
                             object_id="empty1", text="New")
        self.assertEqual(list(self.only_batch(c)[0]), ["insertText"])

    def test_set_text_table_cells(self):
        c, _ = self.run_tool("slides_set_text", presentation_id="p1",
                             object_id="tbl", text="x", row=0, column=1)
        reqs = self.only_batch(c)
        self.assertEqual(list(reqs[0]), ["insertText"])
        self.assertEqual(reqs[0]["insertText"]["cellLocation"],
                         {"rowIndex": 0, "columnIndex": 1})
        c, _ = self.run_tool("slides_set_text", presentation_id="p1",
                             object_id="tbl", text="x", row=0, column=0)
        self.assertIn("deleteText", self.only_batch(c)[0])

    def test_speaker_notes(self):
        c, r = self.run_tool("slides_set_speaker_notes", presentation_id="p1",
                             slide_id="s1", text="new notes")
        reqs = self.only_batch(c)
        self.assertEqual(reqs[0]["deleteText"]["objectId"], "notes1")
        self.assertEqual(reqs[1]["insertText"]["text"], "new notes")

    def test_text_box_with_style(self):
        c, r = self.run_tool("slides_create_text_box", presentation_id="p1", slide_id="s1",
                             x=50, y=60, width=200, height=40, text="hi", bold=True,
                             font_size=24, color="#ff0000", alignment="CENTER")
        reqs = self.only_batch(c)
        shape = reqs[0]["createShape"]
        self.assertEqual(shape["shapeType"], "TEXT_BOX")
        tf = shape["elementProperties"]["transform"]
        self.assertEqual((tf["translateX"], tf["translateY"], tf["unit"]), (50.0, 60.0, "PT"))
        style = reqs[2]["updateTextStyle"]
        self.assertEqual(style["fields"], "bold,fontSize,foregroundColor")
        self.assertEqual(style["style"]["foregroundColor"]["opaqueColor"]["rgbColor"],
                         {"red": 1.0, "green": 0.0, "blue": 0.0})
        self.assertEqual(reqs[3]["updateParagraphStyle"]["fields"], "alignment")
        self.assertEqual(r["object_id"], shape["objectId"])

    def test_shape_properties(self):
        c, _ = self.run_tool("slides_create_shape", presentation_id="p1", slide_id="s1",
                             shape_type="ELLIPSE", fill_color="#00f", outline_weight=2,
                             content_alignment="MIDDLE")
        upd = self.only_batch(c)[1]["updateShapeProperties"]
        self.assertEqual(upd["fields"],
                         "shapeBackgroundFill.solidFill,outline.weight,contentAlignment")

    def test_table_with_data(self):
        c, _ = self.run_tool("slides_create_table", presentation_id="p1", slide_id="s1",
                             rows=2, columns=2, data=[["h1", "h2"], [1, None]],
                             header_bold=True)
        reqs = self.only_batch(c)
        inserts = [q["insertText"] for q in reqs if "insertText" in q]
        self.assertEqual([(i["text"], i["cellLocation"]["rowIndex"]) for i in inserts],
                         [("h1", 0), ("h2", 0), ("1", 1)])
        self.assertEqual(sum("updateTextStyle" in q for q in reqs), 2)

    def test_image_without_size_keeps_aspect(self):
        c, _ = self.run_tool("slides_create_image", presentation_id="p1", slide_id="s1",
                             image_url="https://x/i.png", x=10, y=10)
        props = self.only_batch(c)[0]["createImage"]["elementProperties"]
        self.assertNotIn("size", props)

    def test_transform_element_absolute(self):
        c, _ = self.run_tool("slides_transform_element", presentation_id="p1",
                             object_id="title1", x=100, width=118.11)
        tf = self.only_batch(c)[0]["updatePageElementTransform"]["transform"]
        self.assertEqual(tf["translateX"], 100.0)
        self.assertAlmostEqual(tf["translateY"], 20.0)
        self.assertAlmostEqual(tf["scaleX"], 0.5, places=3)
        self.assertEqual(tf["scaleY"], 1)

    def test_replace_all_text_multiple(self):
        client = FakeSlidesClient(replies=[{"replaceAllText": {"occurrencesChanged": 2}},
                                           {"replaceAllText": {"occurrencesChanged": 1}}])
        c, r = self.run_tool("slides_replace_all_text", client, presentation_id="p1",
                             find="{{a}}", replace="A", extra_replacements={"{{b}}": "B"})
        self.assertEqual(len(self.only_batch(c)), 2)
        self.assertEqual(r["occurrences_changed"], 3)

    def test_text_style_range(self):
        c, _ = self.run_tool("slides_update_text_style", presentation_id="p1",
                             object_id="title1", start_index=0, end_index=3, italic=True)
        req = self.only_batch(c)[0]["updateTextStyle"]
        self.assertEqual(req["textRange"], {"type": "FIXED_RANGE", "startIndex": 0, "endIndex": 3})

    def test_bullets(self):
        c, _ = self.run_tool("slides_update_paragraph_style", presentation_id="p1",
                             object_id="title1", bullet_preset="BULLET_DISC_CIRCLE_SQUARE")
        self.assertIn("createParagraphBullets", self.only_batch(c)[0])

    def test_modify_table_ops(self):
        for op, key in [("insert_rows", "insertTableRows"),
                        ("insert_columns", "insertTableColumns"),
                        ("delete_row", "deleteTableRow"),
                        ("merge_cells", "mergeTableCells"),
                        ("set_column_width", "updateTableColumnProperties")]:
            c, r = self.run_tool("slides_modify_table", presentation_id="p1",
                                 object_id="tbl", operation=op, width=100)
            self.assertTrue(r["success"], r)
            self.assertIn(key, self.only_batch(c)[0])

    def test_bad_color_is_error(self):
        _, r = self.run_tool("slides_set_background", presentation_id="p1",
                             slide_ids=["s1"], color="red")
        self.assertFalse(r["success"])

    def test_create_presentation_in_folder(self):
        c, r = self.run_tool("slides_create_presentation", title="X", folder_id="F")
        self.assertEqual(c.files, [("new1", {}, "F", "root")])
        self.assertEqual(r["presentationId"], "new1")

    def test_list_query(self):
        c, _ = self.run_tool("slides_list_presentations", name_contains="Bob's")
        self.assertIn("name contains 'Bob\\'s'", c.last_query)

    def test_export_and_thumbnail_to_disk(self):
        with tempfile.TemporaryDirectory() as d:
            _, r = self.run_tool("slides_export", presentation_id="p1",
                                 output_path=os.path.join(d, "x.pdf"))
            self.assertTrue(r["success"])
            with open(r["saved_to"], "rb") as f:
                self.assertEqual(f.read(), b"%PDF fake")
            _, r = self.run_tool("slides_get_thumbnail", presentation_id="p1",
                                 slide_id="s1", include_image=False,
                                 output_path=os.path.join(d, "t.png"))
            self.assertNotIn("_image", r)
            self.assertTrue(os.path.exists(r["saved_to"]))

    def test_export_rejects_unknown_format(self):
        _, r = self.run_tool("slides_export", presentation_id="p1",
                             output_path="/tmp/x", format="gif")
        self.assertFalse(r["success"])

    def test_duplicate_and_reposition(self):
        client = FakeSlidesClient(replies=[{"duplicateObject": {"objectId": "dup"}}])
        c, r = self.run_tool("slides_duplicate_object", client, presentation_id="p1",
                             object_id="s1", insertion_index=0)
        self.assertEqual(r["new_object_id"], "dup")
        self.assertEqual(c.batches[1][0]["updateSlidesPosition"]["slideObjectIds"], ["dup"])

    def test_batch_update_passthrough(self):
        c, r = self.run_tool("slides_batch_update", presentation_id="p1",
                             requests=[{"deleteObject": {"objectId": "x"}}])
        self.assertEqual(self.only_batch(c), [{"deleteObject": {"objectId": "x"}}])


if __name__ == "__main__":
    unittest.main()
