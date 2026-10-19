class FakeSlidesClient:
    """Records batchUpdate requests; serves canned presentation/page JSON."""

    def __init__(self, presentation=None, page=None, replies=None):
        self.presentation = presentation or {"presentationId": "p1", "slides": []}
        self.page = page or {}
        self.replies = replies or []
        self.batches = []
        self.files = []

    def create(self, title):
        return {"presentationId": "new1", "title": title, "slides": [], "layouts": []}

    def get(self, presentation_id, fields=None):
        return self.presentation

    def get_page(self, presentation_id, page_id):
        return self.page

    def batch_update(self, presentation_id, requests):
        self.batches.append(requests)
        return {"replies": self.replies}

    def thumbnail(self, presentation_id, page_id, size):
        return {"contentUrl": "https://example/thumb.png", "width": 800, "height": 450}

    def fetch_url(self, url):
        return b"\x89PNG fake"

    def list_files(self, query, limit):
        self.last_query = query
        return [{"id": "p1", "name": "Deck"}]

    def copy_file(self, file_id, body):
        return {"id": "copy1", "name": body["name"], "webViewLink": "https://x"}

    def update_file(self, file_id, body, add_parents=None, remove_parents=None):
        self.files.append((file_id, body, add_parents, remove_parents))
        return {"id": file_id, "name": body.get("name"), "parents": [add_parents]}

    def get_file(self, file_id, fields):
        return {"parents": ["old"]}

    def share(self, file_id, permission, notify):
        return permission

    def export(self, file_id, mime_type):
        return b"%PDF fake"
