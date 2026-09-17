import json
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer

from anix_llm.api import OllamaClient


def test_openai_chat_and_ollama_status_endpoints():
    requests = []

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path == "/api/version":
                response = {"version": "test"}
            elif self.path == "/api/tags":
                response = {"models": [{"name": "qwen:test"}]}
            elif self.path == "/api/ps":
                response = {"models": []}
            else:
                self.send_error(404)
                return
            self._send(response)

        def do_POST(self):
            length = int(self.headers["Content-Length"])
            requests.append(json.loads(self.rfile.read(length)))
            self._send({"choices": [{"message": {"content": "Normal text response"}}]})

        def _send(self, response):
            body = json.dumps(response).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, format, *args):
            pass

    server = HTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(
        target=lambda: [server.handle_request() for _ in range(4)]
    )
    thread.start()
    client = OllamaClient(
        f"http://127.0.0.1:{server.server_port}", "qwen:test", timeout=5
    )

    assert client.version() == "test"
    assert client.installed_models() == ["qwen:test"]
    assert client.running_models() == []
    assert (
        client.chat(
            [{"role": "user", "content": "Question"}],
            max_tokens=100,
            temperature=0.2,
            reasoning_effort="none",
        )
        == "Normal text response"
    )
    thread.join(timeout=5)
    server.server_close()

    assert requests[0]["model"] == "qwen:test"
    assert requests[0]["reasoning_effort"] == "none"
