#!/usr/bin/env python3
# Google Slides MCP Server - gives Claude Code (and Codex) full read/write
# control over Google Slides decks. Stdlib stdio JSON-RPC (mirrors
# gmail-mcp-server); the Google work goes through google-api-python-client
# using the same authorized-user refresh file as the other Google MCP servers.
#
# Design: handle_tool_call() builds Slides API batchUpdate requests and calls a
# duck-typed client, so the request-building layer is unit-tested against a
# fake with no network. The real SlidesClient is only constructed in main().
#
# Units: every position/size argument is in points (pt). A standard 16:9 deck
# is 720 x 405 pt. Colors are "#RRGGBB" hex strings.
import base64
import json
import os
import sys
import urllib.request
import uuid

EMU_PER_PT = 12700
PRESENTATION_MIME = "application/vnd.google-apps.presentation"
EXPORT_FORMATS = {
    "pdf": "application/pdf",
    "pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    "odp": "application/vnd.oasis.opendocument.presentation",
    "txt": "text/plain",
}


class SlidesClient:
    """Thin adapter over the Slides v1 and Drive v3 discovery clients."""

    def __init__(self, token_path, credentials_path=None):
        # Imported lazily so the module (and its tests) load without Google libs.
        from google.auth.transport.requests import Request
        from google.oauth2.credentials import Credentials
        from googleapiclient.discovery import build

        with open(os.path.expanduser(token_path)) as f:
            info = json.load(f)
        if "client_id" not in info and credentials_path:
            with open(os.path.expanduser(credentials_path)) as f:
                secrets = json.load(f)
            secrets = secrets.get("installed") or secrets.get("web") or secrets
            info.setdefault("client_id", secrets["client_id"])
            info.setdefault("client_secret", secrets["client_secret"])
        # Keep the scopes the token was granted with; its `drive` scope covers
        # the Slides API. Refreshed tokens stay in memory so this server never
        # races the other Google tools that own the refresh file.
        creds = Credentials.from_authorized_user_info(info)
        if not creds.valid:
            creds.refresh(Request())
        self.creds = creds
        self.slides = build("slides", "v1", credentials=creds, cache_discovery=False)
        self.drive = build("drive", "v3", credentials=creds, cache_discovery=False)

    def create(self, title):
        return self.slides.presentations().create(body={"title": title}).execute()

    def get(self, presentation_id, fields=None):
        kwargs = {"presentationId": presentation_id}
        if fields:
            kwargs["fields"] = fields
        return self.slides.presentations().get(**kwargs).execute()

    def get_page(self, presentation_id, page_id):
        return (
            self.slides.presentations()
            .pages()
            .get(presentationId=presentation_id, pageObjectId=page_id)
            .execute()
        )

    def batch_update(self, presentation_id, requests):
        return (
            self.slides.presentations()
            .batchUpdate(presentationId=presentation_id, body={"requests": requests})
            .execute()
        )

    def thumbnail(self, presentation_id, page_id, size):
        return (
            self.slides.presentations()
            .pages()
            .getThumbnail(
                presentationId=presentation_id,
                pageObjectId=page_id,
                thumbnailProperties_thumbnailSize=size,
                thumbnailProperties_mimeType="PNG",
            )
            .execute()
        )

    def fetch_url(self, url):
        with urllib.request.urlopen(url, timeout=60) as resp:
            return resp.read()

    def list_files(self, query, limit):
        resp = (
            self.drive.files()
            .list(
                q=query,
                pageSize=min(limit, 1000),
                orderBy="modifiedTime desc",
                fields="files(id,name,modifiedTime,webViewLink,owners(emailAddress))",
                supportsAllDrives=True,
                includeItemsFromAllDrives=True,
            )
            .execute()
        )
        return resp.get("files", [])

    def copy_file(self, file_id, body):
        return (
            self.drive.files()
            .copy(fileId=file_id, body=body, fields="id,name,webViewLink",
                  supportsAllDrives=True)
            .execute()
        )

    def update_file(self, file_id, body, add_parents=None, remove_parents=None):
        kwargs = {"fileId": file_id, "body": body, "supportsAllDrives": True,
                  "fields": "id,name,parents,trashed,webViewLink"}
        if add_parents:
            kwargs["addParents"] = add_parents
        if remove_parents:
            kwargs["removeParents"] = remove_parents
        return self.drive.files().update(**kwargs).execute()

    def get_file(self, file_id, fields):
        return (
            self.drive.files()
            .get(fileId=file_id, fields=fields, supportsAllDrives=True)
            .execute()
        )

    def share(self, file_id, permission, notify):
        return (
            self.drive.permissions()
            .create(fileId=file_id, body=permission, sendNotificationEmail=notify,
                    fields="id,role,type,emailAddress", supportsAllDrives=True)
            .execute()
        )

    def export(self, file_id, mime_type):
        return self.drive.files().export(fileId=file_id, mimeType=mime_type).execute()


# ---------------------------------------------------------------------------
# Request-building helpers
# ---------------------------------------------------------------------------


def _new_id(prefix):
    return f"{prefix}_{uuid.uuid4().hex[:20]}"


def _pt(value):
    return {"magnitude": float(value), "unit": "PT"}


def _element_properties(page_id, args, default_w=300, default_h=100):
    return {
        "pageObjectId": page_id,
        "size": {"width": _pt(args.get("width", default_w)),
                 "height": _pt(args.get("height", default_h))},
        "transform": {"scaleX": 1, "scaleY": 1, "shearX": 0, "shearY": 0,
                      "translateX": float(args.get("x", 0)),
                      "translateY": float(args.get("y", 0)), "unit": "PT"},
    }


def _rgb(hex_color):
    h = hex_color.lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    if len(h) != 6 or any(c not in "0123456789abcdefABCDEF" for c in h):
        raise ValueError(f"Invalid color {hex_color!r}; expected #RRGGBB")
    return {"red": int(h[0:2], 16) / 255, "green": int(h[2:4], 16) / 255,
            "blue": int(h[4:6], 16) / 255}


def _opaque(hex_color):
    return {"opaqueColor": {"rgbColor": _rgb(hex_color)}}


def _cell(args):
    if args.get("row") is None and args.get("column") is None:
        return None
    return {"rowIndex": int(args.get("row", 0)), "columnIndex": int(args.get("column", 0))}


def _text_range(args):
    start, end = args.get("start_index"), args.get("end_index")
    if start is None and end is None:
        return {"type": "ALL"}
    if end is None:
        return {"type": "FROM_START_INDEX", "startIndex": int(start)}
    return {"type": "FIXED_RANGE", "startIndex": int(start or 0), "endIndex": int(end)}


def _with_cell(request_body, args):
    cell = _cell(args)
    if cell:
        request_body["cellLocation"] = cell
    return request_body


def _emu_to_pt(dim):
    if not dim:
        return None
    mag = dim.get("magnitude", 0)
    return round(mag / EMU_PER_PT, 2) if dim.get("unit", "EMU") == "EMU" else mag


def _text_of(text_obj):
    if not text_obj:
        return ""
    return "".join(
        el.get("textRun", {}).get("content", "")
        for el in text_obj.get("textElements", [])
    )


def _summarize_element(el):
    out = {"objectId": el.get("objectId")}
    size, tf = el.get("size") or {}, el.get("transform") or {}
    scale_x, scale_y = tf.get("scaleX", 1), tf.get("scaleY", 1)
    width, height = _emu_to_pt(size.get("width")), _emu_to_pt(size.get("height"))
    unit_pt = tf.get("unit", "EMU") == "PT"
    out["frame_pt"] = {
        "x": round(tf.get("translateX", 0) / (1 if unit_pt else EMU_PER_PT), 2),
        "y": round(tf.get("translateY", 0) / (1 if unit_pt else EMU_PER_PT), 2),
        "width": round(width * scale_x, 2) if width is not None else None,
        "height": round(height * scale_y, 2) if height is not None else None,
    }
    if el.get("title") or el.get("description"):
        out["alt_text"] = {"title": el.get("title"), "description": el.get("description")}
    if "shape" in el:
        shape = el["shape"]
        out["kind"] = "shape"
        out["shapeType"] = shape.get("shapeType")
        if shape.get("placeholder"):
            out["placeholder"] = shape["placeholder"].get("type")
        text = _text_of(shape.get("text"))
        if text:
            out["text"] = text
    elif "table" in el:
        table = el["table"]
        out["kind"] = "table"
        out["rows"], out["columns"] = table.get("rows"), table.get("columns")
        out["cells"] = [
            [_text_of(c.get("text")) for c in row.get("tableCells", [])]
            for row in table.get("tableRows", [])
        ]
    elif "image" in el:
        out["kind"] = "image"
        out["sourceUrl"] = el["image"].get("sourceUrl")
    elif "line" in el:
        out["kind"] = "line"
        out["lineType"] = el["line"].get("lineType")
    elif "video" in el:
        out["kind"] = "video"
        out["video"] = {k: el["video"].get(k) for k in ("source", "id", "url")}
    elif "sheetsChart" in el:
        out["kind"] = "sheetsChart"
        out["spreadsheetId"] = el["sheetsChart"].get("spreadsheetId")
        out["chartId"] = el["sheetsChart"].get("chartId")
    elif "elementGroup" in el:
        out["kind"] = "group"
        out["children"] = [
            _summarize_element(c) for c in el["elementGroup"].get("children", [])
        ]
    elif "wordArt" in el:
        out["kind"] = "wordArt"
        out["text"] = el["wordArt"].get("renderedText")
    return out


def _speaker_notes(slide):
    notes_page = slide.get("slideProperties", {}).get("notesPage", {})
    notes_id = notes_page.get("notesProperties", {}).get("speakerNotesObjectId")
    for el in notes_page.get("pageElements", []):
        if el.get("objectId") == notes_id:
            return notes_id, _text_of(el.get("shape", {}).get("text"))
    return notes_id, ""


def _summarize_slide(slide, index=None):
    notes_id, notes = _speaker_notes(slide)
    out = {
        "objectId": slide.get("objectId"),
        "layoutObjectId": slide.get("slideProperties", {}).get("layoutObjectId"),
        "elements": [_summarize_element(e) for e in slide.get("pageElements", [])],
        "speakerNotesObjectId": notes_id,
        "speakerNotes": notes,
    }
    if index is not None:
        out = {"index": index, **out}
    return out


def _summarize_presentation(p):
    size = p.get("pageSize", {})
    return {
        "presentationId": p.get("presentationId"),
        "title": p.get("title"),
        "url": f"https://docs.google.com/presentation/d/{p.get('presentationId')}/edit",
        "pageSize_pt": {"width": _emu_to_pt(size.get("width")),
                        "height": _emu_to_pt(size.get("height"))},
        "layouts": [
            {"objectId": lay.get("objectId"),
             "name": lay.get("layoutProperties", {}).get("name"),
             "displayName": lay.get("layoutProperties", {}).get("displayName")}
            for lay in p.get("layouts", [])
        ],
        "slides": [_summarize_slide(s, i) for i, s in enumerate(p.get("slides", []))],
    }


def _find_element(elements, object_id):
    for el in elements:
        if el.get("objectId") == object_id:
            return el
        found = _find_element(el.get("elementGroup", {}).get("children", []), object_id)
        if found:
            return found
    return None


def _locate(presentation, object_id):
    """Find a page element (including speaker-notes shapes) anywhere in a deck."""
    for slide in presentation.get("slides", []):
        found = _find_element(slide.get("pageElements", []), object_id)
        if found:
            return found
        notes = slide.get("slideProperties", {}).get("notesPage", {})
        found = _find_element(notes.get("pageElements", []), object_id)
        if found:
            return found
    for page in presentation.get("layouts", []) + presentation.get("masters", []):
        found = _find_element(page.get("pageElements", []), object_id)
        if found:
            return found
    return None


def _has_text(element, args):
    if element is None:
        return False
    if "table" in element:
        cell = _cell(args) or {"rowIndex": 0, "columnIndex": 0}
        try:
            row = element["table"]["tableRows"][cell["rowIndex"]]
            target = row["tableCells"][cell["columnIndex"]]
        except (KeyError, IndexError):
            return False
        return bool(_text_of(target.get("text")))
    return bool(_text_of(element.get("shape", {}).get("text")))


def _set_text_requests(presentation, object_id, text, args):
    """Replace all text in a shape / table cell. Deleting from an empty shape
    is an API error, so only emit deleteText when there is existing text."""
    reqs = []
    if _has_text(_locate(presentation, object_id), args):
        reqs.append({"deleteText": _with_cell(
            {"objectId": object_id, "textRange": {"type": "ALL"}}, args)})
    if text:
        reqs.append({"insertText": _with_cell(
            {"objectId": object_id, "insertionIndex": 0, "text": text}, args)})
    return reqs


def _text_style(args):
    style, fields = {}, []
    for key in ("bold", "italic", "underline", "strikethrough", "smallCaps"):
        snake = {"smallCaps": "small_caps"}.get(key, key)
        if args.get(snake) is not None:
            style[key] = bool(args[snake])
            fields.append(key)
    if args.get("font_size") is not None:
        style["fontSize"] = _pt(args["font_size"])
        fields.append("fontSize")
    if args.get("font_family"):
        style["fontFamily"] = args["font_family"]
        fields.append("fontFamily")
    if args.get("color"):
        style["foregroundColor"] = _opaque(args["color"])
        fields.append("foregroundColor")
    if args.get("background_color"):
        style["backgroundColor"] = _opaque(args["background_color"])
        fields.append("backgroundColor")
    if args.get("link_url") is not None:
        style["link"] = {"url": args["link_url"]} if args["link_url"] else None
        fields.append("link")
    if args.get("baseline_offset"):
        style["baselineOffset"] = args["baseline_offset"]
        fields.append("baselineOffset")
    return style, fields


def _paragraph_style(args):
    style, fields = {}, []
    mapping = {
        "alignment": ("alignment", lambda v: v),
        "line_spacing": ("lineSpacing", float),
        "space_above": ("spaceAbove", _pt),
        "space_below": ("spaceBelow", _pt),
        "indent_start": ("indentStart", _pt),
        "indent_first_line": ("indentFirstLine", _pt),
        "direction": ("direction", lambda v: v),
    }
    for arg, (field, conv) in mapping.items():
        if args.get(arg) is not None:
            style[field] = conv(args[arg])
            fields.append(field)
    return style, fields


def _shape_properties(args):
    props, fields = {}, []
    if args.get("fill_color"):
        props["shapeBackgroundFill"] = {"solidFill": {
            "color": {"rgbColor": _rgb(args["fill_color"])},
            "alpha": float(args.get("fill_alpha", 1))}}
        fields.append("shapeBackgroundFill.solidFill")
    elif args.get("fill_transparent"):
        props["shapeBackgroundFill"] = {"propertyState": "NOT_RENDERED"}
        fields.append("shapeBackgroundFill.propertyState")
    outline = {}
    if args.get("outline_color"):
        outline["outlineFill"] = {"solidFill": {"color": {"rgbColor": _rgb(args["outline_color"])}}}
        fields.append("outline.outlineFill.solidFill")
    if args.get("outline_weight") is not None:
        outline["weight"] = _pt(args["outline_weight"])
        fields.append("outline.weight")
    if args.get("outline_dash"):
        outline["dashStyle"] = args["outline_dash"]
        fields.append("outline.dashStyle")
    if args.get("outline_transparent"):
        outline["propertyState"] = "NOT_RENDERED"
        fields.append("outline.propertyState")
    if outline:
        props["outline"] = outline
    if args.get("content_alignment"):
        props["contentAlignment"] = args["content_alignment"]
        fields.append("contentAlignment")
    if args.get("autofit") is not None:
        props["autofit"] = {"autofitType": args["autofit"]}
        fields.append("autofit.autofitType")
    if args.get("link_url"):
        props["link"] = {"url": args["link_url"]}
        fields.append("link")
    if args.get("link_slide_id"):
        props["link"] = {"pageObjectId": args["link_slide_id"]}
        fields.append("link")
    return props, fields


def _require(args, *keys):
    missing = [k for k in keys if args.get(k) in (None, "")]
    if missing:
        raise ValueError(f"Missing required argument(s): {', '.join(missing)}")


def _replies(resp):
    return resp.get("replies", []) if isinstance(resp, dict) else []


# ---------------------------------------------------------------------------
# Tool dispatch
# ---------------------------------------------------------------------------


def _create_element(args, kind, build_request, default_w=300, default_h=100):
    _require(args, "presentation_id", "slide_id")
    obj_id = args.get("object_id") or _new_id(kind)
    props = _element_properties(args["slide_id"], args, default_w, default_h)
    requests = [build_request(obj_id, props)]
    return obj_id, requests


def handle_tool_call(client, name, args):
    """Run one tool. Returns a JSON-able dict; an "_image" key (base64 PNG)
    is lifted into an MCP image content block by handle_request()."""
    try:
        return _dispatch(client, name, args or {})
    except Exception as e:  # surfaced to the agent as an error result
        detail = str(e)
        content = getattr(e, "content", None)
        if content:
            try:
                detail = json.loads(content).get("error", {}).get("message", detail)
            except (ValueError, AttributeError):
                pass
        print(f"Error in {name}: {type(e).__name__}: {detail}", file=sys.stderr)
        return {"success": False, "error": detail}


def _dispatch(client, name, a):
    pid = a.get("presentation_id")

    # -- presentations ------------------------------------------------------
    if name == "slides_list_presentations":
        q = [f"mimeType='{PRESENTATION_MIME}'", "trashed=false"]
        if a.get("name_contains"):
            q.append("name contains '{}'".format(a["name_contains"].replace("'", "\\'")))
        if a.get("folder_id"):
            q.append(f"'{a['folder_id']}' in parents")
        files = client.list_files(" and ".join(q), int(a.get("limit", 25)))
        return {"success": True, "presentations": files}

    if name == "slides_create_presentation":
        _require(a, "title")
        p = client.create(a["title"])
        if a.get("folder_id"):
            client.update_file(p["presentationId"], {}, add_parents=a["folder_id"],
                               remove_parents="root")
        return {"success": True, **_summarize_presentation(p)}

    if name == "slides_get_presentation":
        _require(a, "presentation_id")
        if a.get("raw"):
            return {"success": True, "presentation": client.get(pid, a.get("fields"))}
        return {"success": True, **_summarize_presentation(client.get(pid))}

    if name == "slides_get_slide":
        _require(a, "presentation_id", "slide_id")
        page = client.get_page(pid, a["slide_id"])
        if a.get("raw"):
            return {"success": True, "slide": page}
        return {"success": True, "slide": _summarize_slide(page)}

    if name == "slides_get_thumbnail":
        _require(a, "presentation_id", "slide_id")
        thumb = client.thumbnail(pid, a["slide_id"], a.get("size", "MEDIUM"))
        out = {"success": True, "contentUrl": thumb.get("contentUrl"),
               "width": thumb.get("width"), "height": thumb.get("height")}
        if a.get("output_path") or a.get("include_image", True):
            data = client.fetch_url(thumb["contentUrl"])
            if a.get("output_path"):
                path = os.path.expanduser(a["output_path"])
                with open(path, "wb") as f:
                    f.write(data)
                out["saved_to"] = path
            if a.get("include_image", True):
                out["_image"] = base64.b64encode(data).decode("ascii")
        return out

    if name == "slides_copy_presentation":
        _require(a, "presentation_id", "title")
        body = {"name": a["title"]}
        if a.get("folder_id"):
            body["parents"] = [a["folder_id"]]
        f = client.copy_file(pid, body)
        return {"success": True, "presentationId": f["id"], "title": f["name"],
                "url": f.get("webViewLink")}

    if name == "slides_rename_presentation":
        _require(a, "presentation_id", "title")
        f = client.update_file(pid, {"name": a["title"]})
        return {"success": True, "title": f.get("name")}

    if name == "slides_move_presentation":
        _require(a, "presentation_id", "folder_id")
        parents = client.get_file(pid, "parents").get("parents", [])
        f = client.update_file(pid, {}, add_parents=a["folder_id"],
                               remove_parents=",".join(parents) or None)
        return {"success": True, "parents": f.get("parents")}

    if name == "slides_trash_presentation":
        _require(a, "presentation_id")
        client.update_file(pid, {"trashed": True})
        return {"success": True, "trashed": pid}

    if name == "slides_share_presentation":
        _require(a, "presentation_id")
        role = a.get("role", "reader")
        if a.get("email"):
            perm = {"type": "user", "role": role, "emailAddress": a["email"]}
        elif a.get("domain"):
            perm = {"type": "domain", "role": role, "domain": a["domain"]}
        elif a.get("anyone_with_link"):
            perm = {"type": "anyone", "role": role}
        else:
            raise ValueError("Provide one of email, domain, or anyone_with_link")
        p = client.share(pid, perm, bool(a.get("notify", True)))
        return {"success": True, "permission": p}

    if name == "slides_export":
        _require(a, "presentation_id", "output_path")
        fmt = a.get("format", "pdf").lower()
        if fmt not in EXPORT_FORMATS:
            raise ValueError(f"format must be one of {sorted(EXPORT_FORMATS)}")
        data = client.export(pid, EXPORT_FORMATS[fmt])
        path = os.path.expanduser(a["output_path"])
        with open(path, "wb") as f:
            f.write(data if isinstance(data, bytes) else data.encode("utf-8"))
        return {"success": True, "saved_to": path, "bytes": len(data)}

    # -- slides -------------------------------------------------------------
    if name == "slides_create_slide":
        _require(a, "presentation_id")
        slide_id = a.get("object_id") or _new_id("slide")
        req = {"objectId": slide_id}
        if a.get("insertion_index") is not None:
            req["insertionIndex"] = int(a["insertion_index"])
        if a.get("layout_id"):
            req["slideLayoutReference"] = {"layoutId": a["layout_id"]}
        else:
            req["slideLayoutReference"] = {"predefinedLayout": a.get("layout", "TITLE_AND_BODY")}
        placeholders = {"TITLE": a.get("title"), "BODY": a.get("body"),
                        "SUBTITLE": a.get("subtitle")}
        if a.get("layout") == "TITLE" and not a.get("layout_id"):
            # The TITLE layout's main title placeholder is CENTERED_TITLE.
            placeholders["CENTERED_TITLE"] = placeholders.pop("TITLE")
        mappings, inserts = [], []
        for ph_type, text in placeholders.items():
            if text is None:
                continue
            ph_id = _new_id(ph_type.lower())
            mappings.append({"layoutPlaceholder": {"type": ph_type, "index": 0},
                             "objectId": ph_id})
            if text:
                inserts.append({"insertText": {"objectId": ph_id, "text": text,
                                               "insertionIndex": 0}})
        if mappings:
            req["placeholderIdMappings"] = mappings
        requests = [{"createSlide": req}] + inserts
        if a.get("speaker_notes"):
            client.batch_update(pid, requests)
            notes_id, _ = _speaker_notes(client.get_page(pid, slide_id))
            client.batch_update(pid, [{"insertText": {
                "objectId": notes_id, "text": a["speaker_notes"], "insertionIndex": 0}}])
        else:
            client.batch_update(pid, requests)
        return {"success": True, "slide_id": slide_id,
                "placeholder_ids": {m["layoutPlaceholder"]["type"]: m["objectId"]
                                    for m in mappings}}

    if name == "slides_duplicate_object":
        _require(a, "presentation_id", "object_id")
        req = {"objectId": a["object_id"]}
        resp = client.batch_update(pid, [{"duplicateObject": req}])
        new_id = _replies(resp)[0].get("duplicateObject", {}).get("objectId") if _replies(resp) else None
        if a.get("insertion_index") is not None and new_id:
            client.batch_update(pid, [{"updateSlidesPosition": {
                "slideObjectIds": [new_id], "insertionIndex": int(a["insertion_index"])}}])
        return {"success": True, "new_object_id": new_id}

    if name == "slides_delete_objects":
        _require(a, "presentation_id", "object_ids")
        client.batch_update(pid, [{"deleteObject": {"objectId": o}} for o in a["object_ids"]])
        return {"success": True, "deleted": a["object_ids"]}

    if name == "slides_reorder_slides":
        _require(a, "presentation_id", "slide_ids")
        if a.get("insertion_index") is None:
            raise ValueError("Missing required argument(s): insertion_index")
        client.batch_update(pid, [{"updateSlidesPosition": {
            "slideObjectIds": a["slide_ids"], "insertionIndex": int(a["insertion_index"])}}])
        return {"success": True}

    if name == "slides_set_speaker_notes":
        _require(a, "presentation_id", "slide_id")
        page = client.get_page(pid, a["slide_id"])
        notes_id, existing = _speaker_notes(page)
        if not notes_id:
            raise ValueError(f"Slide {a['slide_id']} has no speaker notes shape")
        reqs = []
        if existing:
            reqs.append({"deleteText": {"objectId": notes_id, "textRange": {"type": "ALL"}}})
        if a.get("text"):
            reqs.append({"insertText": {"objectId": notes_id, "text": a["text"],
                                        "insertionIndex": 0}})
        if reqs:
            client.batch_update(pid, reqs)
        return {"success": True, "speaker_notes_object_id": notes_id}

    if name == "slides_set_background":
        _require(a, "presentation_id", "slide_ids")
        if a.get("image_url"):
            fill = {"stretchedPictureFill": {"contentUrl": a["image_url"]}}
            fields = "pageBackgroundFill.stretchedPictureFill.contentUrl"
        elif a.get("color"):
            fill = {"solidFill": {"color": {"rgbColor": _rgb(a["color"])},
                                  "alpha": float(a.get("alpha", 1))}}
            fields = "pageBackgroundFill.solidFill.color,pageBackgroundFill.solidFill.alpha"
        else:
            raise ValueError("Provide color or image_url")
        client.batch_update(pid, [{"updatePageProperties": {
            "objectId": s, "pageProperties": {"pageBackgroundFill": fill},
            "fields": fields}} for s in a["slide_ids"]])
        return {"success": True}

    # -- element creation ---------------------------------------------------
    if name == "slides_create_text_box":
        obj_id, reqs = _create_element(a, "textbox", lambda oid, props: {
            "createShape": {"objectId": oid, "shapeType": "TEXT_BOX",
                            "elementProperties": props}})
        if a.get("text"):
            reqs.append({"insertText": {"objectId": obj_id, "text": a["text"],
                                        "insertionIndex": 0}})
            style, fields = _text_style(a)
            if fields:
                reqs.append({"updateTextStyle": {"objectId": obj_id, "style": style,
                                                 "textRange": {"type": "ALL"},
                                                 "fields": ",".join(fields)}})
            pstyle, pfields = _paragraph_style(a)
            if pfields:
                reqs.append({"updateParagraphStyle": {"objectId": obj_id, "style": pstyle,
                                                      "textRange": {"type": "ALL"},
                                                      "fields": ",".join(pfields)}})
        client.batch_update(pid, reqs)
        return {"success": True, "object_id": obj_id}

    if name == "slides_create_shape":
        obj_id, reqs = _create_element(a, "shape", lambda oid, props: {
            "createShape": {"objectId": oid, "shapeType": a.get("shape_type", "RECTANGLE"),
                            "elementProperties": props}}, 200, 200)
        if a.get("text"):
            reqs.append({"insertText": {"objectId": obj_id, "text": a["text"],
                                        "insertionIndex": 0}})
        props, fields = _shape_properties(a)
        if fields:
            reqs.append({"updateShapeProperties": {"objectId": obj_id, "shapeProperties": props,
                                                   "fields": ",".join(fields)}})
        client.batch_update(pid, reqs)
        return {"success": True, "object_id": obj_id}

    if name == "slides_create_image":
        _require(a, "image_url")
        obj_id, reqs = _create_element(a, "image", lambda oid, props: {
            "createImage": {"objectId": oid, "url": a["image_url"],
                            "elementProperties": props}})
        if a.get("width") is None and a.get("height") is None:
            # Let Slides pick the native aspect ratio, positioned at x/y.
            props = reqs[0]["createImage"]["elementProperties"]
            props.pop("size")
        client.batch_update(pid, reqs)
        return {"success": True, "object_id": obj_id}

    if name == "slides_create_table":
        _require(a, "rows", "columns")
        obj_id, reqs = _create_element(a, "table", lambda oid, props: {
            "createTable": {"objectId": oid, "rows": int(a["rows"]),
                            "columns": int(a["columns"]), "elementProperties": props}},
            500, 200)
        for r, row in enumerate(a.get("data") or []):
            for c, value in enumerate(row):
                if value not in (None, ""):
                    reqs.append({"insertText": {"objectId": obj_id, "text": str(value),
                                                "insertionIndex": 0,
                                                "cellLocation": {"rowIndex": r, "columnIndex": c}}})
        if a.get("header_bold") and a.get("data"):
            for c in range(int(a["columns"])):
                if c < len(a["data"][0]) and a["data"][0][c] not in (None, ""):
                    reqs.append({"updateTextStyle": {
                        "objectId": obj_id, "cellLocation": {"rowIndex": 0, "columnIndex": c},
                        "style": {"bold": True}, "textRange": {"type": "ALL"},
                        "fields": "bold"}})
        client.batch_update(pid, reqs)
        return {"success": True, "object_id": obj_id}

    if name == "slides_create_line":
        obj_id, reqs = _create_element(a, "line", lambda oid, props: {
            "createLine": {"objectId": oid, "category": a.get("category", "STRAIGHT"),
                           "elementProperties": props}}, 200, 0)
        line_props, fields = {}, []
        if a.get("color"):
            line_props["lineFill"] = {"solidFill": {"color": {"rgbColor": _rgb(a["color"])}}}
            fields.append("lineFill.solidFill.color")
        if a.get("weight") is not None:
            line_props["weight"] = _pt(a["weight"])
            fields.append("weight")
        if a.get("dash_style"):
            line_props["dashStyle"] = a["dash_style"]
            fields.append("dashStyle")
        for end in ("start_arrow", "end_arrow"):
            if a.get(end):
                key = "startArrow" if end == "start_arrow" else "endArrow"
                line_props[key] = a[end]
                fields.append(key)
        if fields:
            reqs.append({"updateLineProperties": {"objectId": obj_id,
                                                  "lineProperties": line_props,
                                                  "fields": ",".join(fields)}})
        client.batch_update(pid, reqs)
        return {"success": True, "object_id": obj_id}

    if name == "slides_create_video":
        _require(a, "video_id")
        obj_id, reqs = _create_element(a, "video", lambda oid, props: {
            "createVideo": {"objectId": oid, "source": a.get("source", "YOUTUBE"),
                            "id": a["video_id"], "elementProperties": props}}, 480, 270)
        client.batch_update(pid, reqs)
        return {"success": True, "object_id": obj_id}

    if name == "slides_create_sheets_chart":
        _require(a, "spreadsheet_id")
        if a.get("chart_id") is None:
            raise ValueError("Missing required argument(s): chart_id")
        obj_id, reqs = _create_element(a, "chart", lambda oid, props: {
            "createSheetsChart": {"objectId": oid, "spreadsheetId": a["spreadsheet_id"],
                                  "chartId": int(a["chart_id"]),
                                  "linkingMode": "LINKED" if a.get("linked", True)
                                  else "NOT_LINKED_IMAGE",
                                  "elementProperties": props}}, 480, 300)
        client.batch_update(pid, reqs)
        return {"success": True, "object_id": obj_id}

    # -- text -----------------------------------------------------------------
    if name == "slides_set_text":
        _require(a, "presentation_id", "object_id")
        presentation = client.get(pid)
        reqs = _set_text_requests(presentation, a["object_id"], a.get("text", ""), a)
        if reqs:
            client.batch_update(pid, reqs)
        return {"success": True}

    if name == "slides_insert_text":
        _require(a, "presentation_id", "object_id", "text")
        req = {"objectId": a["object_id"], "text": a["text"]}
        if a.get("insertion_index") is not None:
            req["insertionIndex"] = int(a["insertion_index"])
        client.batch_update(pid, [{"insertText": _with_cell(req, a)}])
        return {"success": True}

    if name == "slides_delete_text":
        _require(a, "presentation_id", "object_id")
        client.batch_update(pid, [{"deleteText": _with_cell(
            {"objectId": a["object_id"], "textRange": _text_range(a)}, a)}])
        return {"success": True}

    if name == "slides_replace_all_text":
        _require(a, "presentation_id", "find")
        reqs = []
        for find, replace in [(a["find"], a.get("replace", ""))] + [
            (k, v) for k, v in (a.get("extra_replacements") or {}).items()
        ]:
            req = {"containsText": {"text": find, "matchCase": bool(a.get("match_case", True))},
                   "replaceText": replace}
            if a.get("slide_ids"):
                req["pageObjectIds"] = a["slide_ids"]
            reqs.append({"replaceAllText": req})
        resp = client.batch_update(pid, reqs)
        counts = [r.get("replaceAllText", {}).get("occurrencesChanged", 0) for r in _replies(resp)]
        return {"success": True, "occurrences_changed": sum(counts)}

    if name == "slides_replace_shapes_with_image":
        _require(a, "presentation_id", "find", "image_url")
        req = {"containsText": {"text": a["find"], "matchCase": bool(a.get("match_case", True))},
               "imageUrl": a["image_url"],
               "imageReplaceMethod": a.get("replace_method", "CENTER_INSIDE")}
        if a.get("slide_ids"):
            req["pageObjectIds"] = a["slide_ids"]
        resp = client.batch_update(pid, [{"replaceAllShapesWithImage": req}])
        changed = sum(r.get("replaceAllShapesWithImage", {}).get("occurrencesChanged", 0)
                      for r in _replies(resp))
        return {"success": True, "occurrences_changed": changed}

    if name == "slides_update_text_style":
        _require(a, "presentation_id", "object_id")
        style, fields = _text_style(a)
        if not fields:
            raise ValueError("No style properties given")
        client.batch_update(pid, [{"updateTextStyle": _with_cell(
            {"objectId": a["object_id"], "style": style, "textRange": _text_range(a),
             "fields": ",".join(fields)}, a)}])
        return {"success": True, "fields": fields}

    if name == "slides_update_paragraph_style":
        _require(a, "presentation_id", "object_id")
        reqs = []
        style, fields = _paragraph_style(a)
        if fields:
            reqs.append({"updateParagraphStyle": _with_cell(
                {"objectId": a["object_id"], "style": style, "textRange": _text_range(a),
                 "fields": ",".join(fields)}, a)})
        if a.get("bullet_preset"):
            reqs.append({"createParagraphBullets": _with_cell(
                {"objectId": a["object_id"], "textRange": _text_range(a),
                 "bulletPreset": a["bullet_preset"]}, a)})
        elif a.get("remove_bullets"):
            reqs.append({"deleteParagraphBullets": _with_cell(
                {"objectId": a["object_id"], "textRange": _text_range(a)}, a)})
        if not reqs:
            raise ValueError("No paragraph properties given")
        client.batch_update(pid, reqs)
        return {"success": True}

    # -- element properties --------------------------------------------------
    if name == "slides_update_shape_properties":
        _require(a, "presentation_id", "object_id")
        props, fields = _shape_properties(a)
        if not fields:
            raise ValueError("No shape properties given")
        client.batch_update(pid, [{"updateShapeProperties": {
            "objectId": a["object_id"], "shapeProperties": props,
            "fields": ",".join(fields)}}])
        return {"success": True}

    if name == "slides_transform_element":
        _require(a, "presentation_id", "object_id")
        presentation = client.get(pid)
        el = _locate(presentation, a["object_id"])
        if el is None:
            raise ValueError(f"Element {a['object_id']} not found")
        size, tf = el.get("size") or {}, dict(el.get("transform") or {})
        to_pt = (lambda v: v) if tf.get("unit") == "PT" else (lambda v: v / EMU_PER_PT)
        cur = {"x": to_pt(tf.get("translateX", 0)), "y": to_pt(tf.get("translateY", 0)),
               "sx": tf.get("scaleX", 1), "sy": tf.get("scaleY", 1)}
        new_tf = {"scaleX": cur["sx"], "scaleY": cur["sy"],
                  "shearX": tf.get("shearX", 0), "shearY": tf.get("shearY", 0),
                  "translateX": float(a.get("x", cur["x"])),
                  "translateY": float(a.get("y", cur["y"])), "unit": "PT"}
        base_w, base_h = _emu_to_pt(size.get("width")), _emu_to_pt(size.get("height"))
        if a.get("width") is not None:
            if not base_w:
                raise ValueError("Element has no intrinsic width to scale")
            new_tf["scaleX"] = float(a["width"]) / base_w
        if a.get("height") is not None:
            if not base_h:
                raise ValueError("Element has no intrinsic height to scale")
            new_tf["scaleY"] = float(a["height"]) / base_h
        client.batch_update(pid, [{"updatePageElementTransform": {
            "objectId": a["object_id"], "applyMode": "ABSOLUTE", "transform": new_tf}}])
        return {"success": True}

    if name == "slides_set_alt_text":
        _require(a, "presentation_id", "object_id")
        req = {"objectId": a["object_id"]}
        if a.get("title") is not None:
            req["title"] = a["title"]
        if a.get("description") is not None:
            req["description"] = a["description"]
        client.batch_update(pid, [{"updatePageElementAltText": req}])
        return {"success": True}

    if name == "slides_update_image_properties":
        _require(a, "presentation_id", "object_id")
        props, fields = {}, []
        for arg, field in (("brightness", "brightness"), ("contrast", "contrast"),
                           ("transparency", "transparency")):
            if a.get(arg) is not None:
                props[field] = float(a[arg])
                fields.append(field)
        if a.get("link_url"):
            props["link"] = {"url": a["link_url"]}
            fields.append("link")
        if a.get("outline_color"):
            props["outline"] = {"outlineFill": {"solidFill": {
                "color": {"rgbColor": _rgb(a["outline_color"])}}}}
            fields.append("outline.outlineFill.solidFill.color")
        if not fields:
            raise ValueError("No image properties given")
        client.batch_update(pid, [{"updateImageProperties": {
            "objectId": a["object_id"], "imageProperties": props,
            "fields": ",".join(fields)}}])
        return {"success": True}

    if name == "slides_replace_image":
        _require(a, "presentation_id", "object_id", "image_url")
        client.batch_update(pid, [{"replaceImage": {
            "imageObjectId": a["object_id"], "url": a["image_url"],
            "imageReplaceMethod": a.get("replace_method", "CENTER_INSIDE")}}])
        return {"success": True}

    if name == "slides_group_objects":
        _require(a, "presentation_id", "object_ids")
        group_id = a.get("group_id") or _new_id("group")
        client.batch_update(pid, [{"groupObjects": {
            "groupObjectId": group_id, "childrenObjectIds": a["object_ids"]}}])
        return {"success": True, "group_id": group_id}

    if name == "slides_ungroup_objects":
        _require(a, "presentation_id", "group_ids")
        client.batch_update(pid, [{"ungroupObjects": {"objectIds": a["group_ids"]}}])
        return {"success": True}

    if name == "slides_set_z_order":
        _require(a, "presentation_id", "object_ids", "operation")
        client.batch_update(pid, [{"updatePageElementsZOrder": {
            "pageElementObjectIds": a["object_ids"], "operation": a["operation"]}}])
        return {"success": True}

    # -- tables ---------------------------------------------------------------
    if name == "slides_modify_table":
        _require(a, "presentation_id", "object_id", "operation")
        op, tid = a["operation"], a["object_id"]
        loc = {"rowIndex": int(a.get("row", 0)), "columnIndex": int(a.get("column", 0))}
        if op in ("insert_rows", "insert_columns"):
            key = "insertTableRows" if op == "insert_rows" else "insertTableColumns"
            body = {"tableObjectId": tid, "cellLocation": loc,
                    "insertBelow" if op == "insert_rows" else "insertRight":
                    bool(a.get("after", True)), "number": int(a.get("count", 1))}
            req = {key: body}
        elif op == "delete_row":
            req = {"deleteTableRow": {"tableObjectId": tid, "cellLocation": loc}}
        elif op == "delete_column":
            req = {"deleteTableColumn": {"tableObjectId": tid, "cellLocation": loc}}
        elif op == "merge_cells":
            req = {"mergeTableCells": {"objectId": tid, "tableRange": {
                "location": loc, "rowSpan": int(a.get("row_span", 1)),
                "columnSpan": int(a.get("column_span", 1))}}}
        elif op == "unmerge_cells":
            req = {"unmergeTableCells": {"objectId": tid, "tableRange": {
                "location": loc, "rowSpan": int(a.get("row_span", 1)),
                "columnSpan": int(a.get("column_span", 1))}}}
        elif op == "style_cells":
            props, fields = {}, []
            if a.get("fill_color"):
                props["tableCellBackgroundFill"] = {"solidFill": {
                    "color": {"rgbColor": _rgb(a["fill_color"])}}}
                fields.append("tableCellBackgroundFill.solidFill.color")
            if a.get("content_alignment"):
                props["contentAlignment"] = a["content_alignment"]
                fields.append("contentAlignment")
            if not fields:
                raise ValueError("style_cells needs fill_color and/or content_alignment")
            req = {"updateTableCellProperties": {
                "objectId": tid, "tableCellProperties": props, "fields": ",".join(fields),
                "tableRange": {"location": loc, "rowSpan": int(a.get("row_span", 1)),
                               "columnSpan": int(a.get("column_span", 1))}}}
        elif op == "set_column_width":
            _require(a, "width")
            req = {"updateTableColumnProperties": {
                "objectId": tid, "columnIndices": [loc["columnIndex"]],
                "tableColumnProperties": {"columnWidth": _pt(a["width"])},
                "fields": "columnWidth"}}
        elif op == "set_row_height":
            _require(a, "height")
            req = {"updateTableRowProperties": {
                "objectId": tid, "rowIndices": [loc["rowIndex"]],
                "tableRowProperties": {"minRowHeight": _pt(a["height"])},
                "fields": "minRowHeight"}}
        else:
            raise ValueError(f"Unknown table operation: {op}")
        client.batch_update(pid, [req])
        return {"success": True}

    # -- escape hatch -----------------------------------------------------------
    if name == "slides_batch_update":
        _require(a, "presentation_id", "requests")
        resp = client.batch_update(pid, a["requests"])
        return {"success": True, "replies": _replies(resp)}

    if name == "slides_refresh_sheets_chart":
        _require(a, "presentation_id", "object_id")
        client.batch_update(pid, [{"refreshSheetsChart": {"objectId": a["object_id"]}}])
        return {"success": True}

    return {"success": False, "error": f"Unknown tool: {name}"}


# ---------------------------------------------------------------------------
# Tool schemas
# ---------------------------------------------------------------------------

_S = {"type": "string"}
_N = {"type": "number"}
_I = {"type": "integer"}
_B = {"type": "boolean"}
_SL = {"type": "array", "items": {"type": "string"}}
_PID = {"presentation_id": {"type": "string", "description": "Presentation (file) ID from the deck URL"}}
_FRAME = {
    "x": {"type": "number", "description": "Left edge, pt (default 0)"},
    "y": {"type": "number", "description": "Top edge, pt (default 0)"},
    "width": {"type": "number", "description": "Width, pt"},
    "height": {"type": "number", "description": "Height, pt"},
    "object_id": {"type": "string", "description": "Optional explicit object ID (5-50 chars)"},
}
_CELL = {
    "row": {"type": "integer", "description": "Table row (only for table cells)"},
    "column": {"type": "integer", "description": "Table column (only for table cells)"},
}
_RANGE = {
    "start_index": {"type": "integer", "description": "Start of text range (omit for all text)"},
    "end_index": {"type": "integer", "description": "End of text range (exclusive)"},
}
_TEXT_STYLE = {
    "bold": _B, "italic": _B, "underline": _B, "strikethrough": _B, "small_caps": _B,
    "font_size": {"type": "number", "description": "pt"},
    "font_family": {"type": "string", "description": "e.g. 'Roboto', 'Arial'"},
    "color": {"type": "string", "description": "#RRGGBB text color"},
    "background_color": {"type": "string", "description": "#RRGGBB highlight"},
    "link_url": {"type": "string", "description": "Hyperlink; empty string removes it"},
    "baseline_offset": {"type": "string", "enum": ["NONE", "SUPERSCRIPT", "SUBSCRIPT"]},
}
_PARA_STYLE = {
    "alignment": {"type": "string", "enum": ["START", "CENTER", "END", "JUSTIFIED"]},
    "line_spacing": {"type": "number", "description": "Percent, 100 = single"},
    "space_above": {"type": "number", "description": "pt"},
    "space_below": {"type": "number", "description": "pt"},
    "indent_start": {"type": "number", "description": "pt"},
    "indent_first_line": {"type": "number", "description": "pt"},
    "direction": {"type": "string", "enum": ["LEFT_TO_RIGHT", "RIGHT_TO_LEFT"]},
}
_SHAPE_PROPS = {
    "fill_color": {"type": "string", "description": "#RRGGBB background fill"},
    "fill_alpha": {"type": "number", "description": "0-1 fill opacity"},
    "fill_transparent": {"type": "boolean", "description": "Remove fill"},
    "outline_color": {"type": "string", "description": "#RRGGBB"},
    "outline_weight": {"type": "number", "description": "pt"},
    "outline_dash": {"type": "string", "enum": ["SOLID", "DOT", "DASH", "DASH_DOT", "LONG_DASH", "LONG_DASH_DOT"]},
    "outline_transparent": {"type": "boolean", "description": "Remove outline"},
    "content_alignment": {"type": "string", "enum": ["TOP", "MIDDLE", "BOTTOM"]},
    "autofit": {"type": "string", "enum": ["NONE", "TEXT_AUTOFIT", "SHAPE_AUTOFIT"]},
    "link_url": {"type": "string", "description": "Make the shape a hyperlink"},
    "link_slide_id": {"type": "string", "description": "Make the shape link to a slide"},
}


def _tool(name, description, properties, required=()):
    return {"name": name, "description": description,
            "inputSchema": {"type": "object", "properties": properties,
                            "required": list(required)}}


TOOLS = [
    _tool("slides_list_presentations",
          "List Google Slides presentations in Drive (newest first).",
          {"name_contains": _S, "folder_id": _S,
           "limit": {"type": "integer", "description": "Max results (default 25)"}}),
    _tool("slides_create_presentation",
          "Create a new, empty presentation (one blank title slide). Returns its "
          "ID, URL, layouts, and slide summary.",
          {"title": _S, "folder_id": {"type": "string", "description": "Optional Drive folder"}},
          ["title"]),
    _tool("slides_get_presentation",
          "Read a deck: title, page size, available layouts, and every slide with "
          "element IDs, kinds, frames (pt), text, table cells, and speaker notes. "
          "Use raw=true for the full API JSON (optionally narrowed with `fields`).",
          {**_PID, "raw": _B, "fields": {"type": "string", "description": "API field mask for raw mode"}},
          ["presentation_id"]),
    _tool("slides_get_slide", "Read one slide (summary, or raw=true for full JSON).",
          {**_PID, "slide_id": _S, "raw": _B}, ["presentation_id", "slide_id"]),
    _tool("slides_get_thumbnail",
          "Render a slide to PNG so you can see it. Returns the image inline by "
          "default; optionally saves it to output_path.",
          {**_PID, "slide_id": _S,
           "size": {"type": "string", "enum": ["SMALL", "MEDIUM", "LARGE"]},
           "include_image": {"type": "boolean", "description": "Return image content (default true)"},
           "output_path": {"type": "string", "description": "Local path to save the PNG"}},
          ["presentation_id", "slide_id"]),
    _tool("slides_copy_presentation", "Copy a deck (e.g. from a template).",
          {**_PID, "title": _S, "folder_id": _S}, ["presentation_id", "title"]),
    _tool("slides_rename_presentation", "Rename a deck.",
          {**_PID, "title": _S}, ["presentation_id", "title"]),
    _tool("slides_move_presentation", "Move a deck to a Drive folder.",
          {**_PID, "folder_id": _S}, ["presentation_id", "folder_id"]),
    _tool("slides_trash_presentation", "Move a deck to the Drive trash (recoverable).",
          _PID, ["presentation_id"]),
    _tool("slides_share_presentation",
          "Share a deck with a user, domain, or anyone with the link.",
          {**_PID, "email": _S, "domain": _S, "anyone_with_link": _B,
           "role": {"type": "string", "enum": ["reader", "commenter", "writer"]},
           "notify": {"type": "boolean", "description": "Email the user (default true)"}},
          ["presentation_id"]),
    _tool("slides_export", "Export a deck to a local file (pdf, pptx, odp, txt).",
          {**_PID, "format": {"type": "string", "enum": sorted(EXPORT_FORMATS)},
           "output_path": _S}, ["presentation_id", "output_path"]),
    _tool("slides_create_slide",
          "Add a slide from a predefined layout (or a deck layout_id), optionally "
          "filling its title/subtitle/body placeholders and speaker notes.",
          {**_PID,
           "layout": {"type": "string", "enum": [
               "BLANK", "CAPTION_ONLY", "TITLE", "TITLE_AND_BODY", "TITLE_AND_TWO_COLUMNS",
               "TITLE_ONLY", "SECTION_HEADER", "SECTION_TITLE_AND_DESCRIPTION",
               "ONE_COLUMN_TEXT", "MAIN_POINT", "BIG_NUMBER"]},
           "layout_id": {"type": "string", "description": "Layout objectId from slides_get_presentation"},
           "insertion_index": {"type": "integer", "description": "0-based position (default end)"},
           "title": _S, "subtitle": _S, "body": _S, "speaker_notes": _S,
           "object_id": _S},
          ["presentation_id"]),
    _tool("slides_duplicate_object",
          "Duplicate a slide or page element; returns the new ID.",
          {**_PID, "object_id": _S,
           "insertion_index": {"type": "integer", "description": "For slides: move the copy here"}},
          ["presentation_id", "object_id"]),
    _tool("slides_delete_objects", "Delete slides and/or page elements by ID.",
          {**_PID, "object_ids": _SL}, ["presentation_id", "object_ids"]),
    _tool("slides_reorder_slides", "Move slides to a new 0-based position.",
          {**_PID, "slide_ids": _SL, "insertion_index": _I},
          ["presentation_id", "slide_ids", "insertion_index"]),
    _tool("slides_set_speaker_notes", "Replace a slide's speaker notes.",
          {**_PID, "slide_id": _S, "text": _S}, ["presentation_id", "slide_id"]),
    _tool("slides_set_background", "Set slide background to a color or image URL.",
          {**_PID, "slide_ids": _SL, "color": _S, "alpha": _N,
           "image_url": {"type": "string", "description": "Publicly accessible image URL"}},
          ["presentation_id", "slide_ids"]),
    _tool("slides_create_text_box",
          "Add a text box with optional text and text/paragraph styling.",
          {**_PID, "slide_id": _S, **_FRAME, "text": _S, **_TEXT_STYLE, **_PARA_STYLE},
          ["presentation_id", "slide_id"]),
    _tool("slides_create_shape",
          "Add a shape (RECTANGLE, ROUND_RECTANGLE, ELLIPSE, TRIANGLE, RIGHT_ARROW, "
          "STAR_5, CLOUD, etc. - any Slides ShapeType) with optional text and styling.",
          {**_PID, "slide_id": _S, **_FRAME, "shape_type": _S, "text": _S, **_SHAPE_PROPS},
          ["presentation_id", "slide_id"]),
    _tool("slides_create_image",
          "Insert an image from a publicly accessible URL (PNG/JPEG/GIF, <50MB). "
          "Omit width/height to keep native aspect ratio.",
          {**_PID, "slide_id": _S, "image_url": _S, **_FRAME},
          ["presentation_id", "slide_id", "image_url"]),
    _tool("slides_create_table",
          "Insert a table, optionally filled from a 2-D `data` array.",
          {**_PID, "slide_id": _S, "rows": _I, "columns": _I, **_FRAME,
           "data": {"type": "array", "items": {"type": "array", "items": {"type": ["string", "number", "null"]}}},
           "header_bold": {"type": "boolean", "description": "Bold the first row"}},
          ["presentation_id", "slide_id", "rows", "columns"]),
    _tool("slides_create_line",
          "Draw a line/connector. The frame's width/height give the line's extent.",
          {**_PID, "slide_id": _S, **_FRAME,
           "category": {"type": "string", "enum": ["STRAIGHT", "BENT", "CURVED"]},
           "color": _S, "weight": {"type": "number", "description": "pt"},
           "dash_style": _S,
           "start_arrow": {"type": "string", "description": "e.g. NONE, FILL_ARROW, STEALTH_ARROW, OPEN_ARROW, FILL_CIRCLE"},
           "end_arrow": _S},
          ["presentation_id", "slide_id"]),
    _tool("slides_create_video", "Embed a YouTube (or Drive) video.",
          {**_PID, "slide_id": _S, "video_id": _S,
           "source": {"type": "string", "enum": ["YOUTUBE", "DRIVE"]}, **_FRAME},
          ["presentation_id", "slide_id", "video_id"]),
    _tool("slides_create_sheets_chart",
          "Embed a chart from a Google Sheet (linked by default).",
          {**_PID, "slide_id": _S, "spreadsheet_id": _S, "chart_id": _I,
           "linked": _B, **_FRAME},
          ["presentation_id", "slide_id", "spreadsheet_id", "chart_id"]),
    _tool("slides_refresh_sheets_chart", "Refresh a linked Sheets chart.",
          {**_PID, "object_id": _S}, ["presentation_id", "object_id"]),
    _tool("slides_set_text",
          "Replace ALL text in a shape, placeholder, speaker-notes shape, or table "
          "cell (pass row/column).",
          {**_PID, "object_id": _S, "text": _S, **_CELL}, ["presentation_id", "object_id"]),
    _tool("slides_insert_text", "Insert text at an index in a shape or table cell.",
          {**_PID, "object_id": _S, "text": _S,
           "insertion_index": {"type": "integer", "description": "Default 0"}, **_CELL},
          ["presentation_id", "object_id", "text"]),
    _tool("slides_delete_text", "Delete a text range (or all text) from a shape or cell.",
          {**_PID, "object_id": _S, **_RANGE, **_CELL}, ["presentation_id", "object_id"]),
    _tool("slides_replace_all_text",
          "Find-and-replace text across the deck (or given slides). Great for "
          "filling {{placeholders}} in template decks; extra_replacements maps more "
          "find->replace pairs.",
          {**_PID, "find": _S, "replace": _S, "match_case": _B, "slide_ids": _SL,
           "extra_replacements": {"type": "object", "additionalProperties": {"type": "string"}}},
          ["presentation_id", "find"]),
    _tool("slides_replace_shapes_with_image",
          "Replace every shape containing `find` text with an image.",
          {**_PID, "find": _S, "image_url": _S, "match_case": _B, "slide_ids": _SL,
           "replace_method": {"type": "string", "enum": ["CENTER_INSIDE", "CENTER_CROP"]}},
          ["presentation_id", "find", "image_url"]),
    _tool("slides_update_text_style",
          "Style text (bold, italic, size, font, color, link...) in a shape or cell, "
          "for all text or a start/end index range.",
          {**_PID, "object_id": _S, **_RANGE, **_CELL, **_TEXT_STYLE},
          ["presentation_id", "object_id"]),
    _tool("slides_update_paragraph_style",
          "Set paragraph alignment/spacing/indent and add or remove bullets.",
          {**_PID, "object_id": _S, **_RANGE, **_CELL, **_PARA_STYLE,
           "bullet_preset": {"type": "string", "description": "e.g. BULLET_DISC_CIRCLE_SQUARE, NUMBERED_DIGIT_ALPHA_ROMAN, BULLET_CHECKBOX"},
           "remove_bullets": _B},
          ["presentation_id", "object_id"]),
    _tool("slides_update_shape_properties",
          "Set a shape's fill, outline, vertical text alignment, autofit, or link.",
          {**_PID, "object_id": _S, **_SHAPE_PROPS}, ["presentation_id", "object_id"]),
    _tool("slides_transform_element",
          "Move and/or resize any page element to an absolute x/y/width/height in pt.",
          {**_PID, "object_id": _S, "x": _N, "y": _N, "width": _N, "height": _N},
          ["presentation_id", "object_id"]),
    _tool("slides_set_alt_text", "Set an element's accessibility title/description.",
          {**_PID, "object_id": _S, "title": _S, "description": _S},
          ["presentation_id", "object_id"]),
    _tool("slides_update_image_properties",
          "Adjust an image's brightness/contrast (-1..1), transparency (0..1), link, outline.",
          {**_PID, "object_id": _S, "brightness": _N, "contrast": _N,
           "transparency": _N, "link_url": _S, "outline_color": _S},
          ["presentation_id", "object_id"]),
    _tool("slides_replace_image", "Swap an existing image for a new URL.",
          {**_PID, "object_id": _S, "image_url": _S,
           "replace_method": {"type": "string", "enum": ["CENTER_INSIDE", "CENTER_CROP"]}},
          ["presentation_id", "object_id", "image_url"]),
    _tool("slides_group_objects", "Group page elements on the same slide.",
          {**_PID, "object_ids": _SL, "group_id": _S}, ["presentation_id", "object_ids"]),
    _tool("slides_ungroup_objects", "Ungroup groups.",
          {**_PID, "group_ids": _SL}, ["presentation_id", "group_ids"]),
    _tool("slides_set_z_order", "Change stacking order of elements.",
          {**_PID, "object_ids": _SL,
           "operation": {"type": "string", "enum": ["BRING_TO_FRONT", "BRING_FORWARD",
                                                   "SEND_BACKWARD", "SEND_TO_BACK"]}},
          ["presentation_id", "object_ids", "operation"]),
    _tool("slides_modify_table",
          "Table structure/styling: insert_rows, insert_columns, delete_row, "
          "delete_column, merge_cells, unmerge_cells, style_cells, set_column_width, "
          "set_row_height. row/column locate the anchor cell.",
          {**_PID, "object_id": _S,
           "operation": {"type": "string", "enum": [
               "insert_rows", "insert_columns", "delete_row", "delete_column",
               "merge_cells", "unmerge_cells", "style_cells", "set_column_width",
               "set_row_height"]},
           **_CELL, "count": _I,
           "after": {"type": "boolean", "description": "Insert below/right (default true)"},
           "row_span": _I, "column_span": _I, "fill_color": _S,
           "content_alignment": {"type": "string", "enum": ["TOP", "MIDDLE", "BOTTOM"]},
           "width": _N, "height": _N},
          ["presentation_id", "object_id", "operation"]),
    _tool("slides_batch_update",
          "Escape hatch: send raw Slides API batchUpdate requests "
          "(https://developers.google.com/slides/api/reference/rest/v1/presentations/request) "
          "for anything the other tools do not cover. Applied atomically.",
          {**_PID, "requests": {"type": "array", "items": {"type": "object"}}},
          ["presentation_id", "requests"]),
]


# ---------------------------------------------------------------------------
# JSON-RPC
# ---------------------------------------------------------------------------


def handle_request(client, request):
    method = request.get("method")
    req_id = request.get("id")
    if method == "initialize":
        result = {"protocolVersion": "2024-11-05",
                  "capabilities": {"tools": {}},
                  "serverInfo": {"name": "google-slides-mcp-server", "version": "1.0.0"}}
    elif method == "tools/list":
        result = {"tools": TOOLS}
    elif method == "tools/call":
        params = request.get("params", {})
        tool_result = handle_tool_call(client, params.get("name"),
                                       params.get("arguments", {}))
        image = tool_result.pop("_image", None)
        content = [{"type": "text", "text": json.dumps(tool_result)}]
        if image:
            content.append({"type": "image", "data": image, "mimeType": "image/png"})
        result = {"content": content, "isError": not tool_result.get("success", False)}
    elif method == "ping":
        result = {}
    else:
        return {"jsonrpc": "2.0", "id": req_id,
                "error": {"code": -32601, "message": f"Method not found: {method}"}}
    return {"jsonrpc": "2.0", "id": req_id, "result": result}


class _LazyClient:
    """Defer Google auth until the first tool call, so a missing/expired token
    surfaces as a tool error instead of the server failing to start."""

    def __init__(self, factory):
        self._factory, self._client = factory, None

    def __getattr__(self, attr):
        if self._client is None:
            self._client = self._factory()
        return getattr(self._client, attr)


def main():
    token_path = os.environ.get("TOKEN_PATH", "~/secrets/google/refresh.json")
    credentials_path = os.environ.get("CREDENTIALS_PATH", "~/secrets/google/client_secrets.json")

    # Keep the real stdout for protocol writes only.
    protocol_out = sys.stdout
    sys.stdout = sys.stderr

    client = _LazyClient(lambda: SlidesClient(token_path, credentials_path))
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            request = json.loads(line)
        except json.JSONDecodeError:
            continue
        if "id" not in request:  # notification - no response
            continue
        response = handle_request(client, request)
        protocol_out.write(json.dumps(response) + "\n")
        protocol_out.flush()


if __name__ == "__main__":
    main()
