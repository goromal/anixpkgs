"""HTTP client for a local Ollama server."""

from __future__ import annotations

import json
import os
import sys
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


class OllamaClient:
    def __init__(self, base_url: str, model: str, timeout: float = 900) -> None:
        normalized_url = base_url.rstrip("/")
        if normalized_url.endswith("/v1"):
            self.root_url = normalized_url[:-3]
            self.openai_url = normalized_url
        else:
            self.root_url = normalized_url
            self.openai_url = f"{normalized_url}/v1"
        self.model = model
        self.timeout = timeout

    def chat(
        self,
        messages: list[dict[str, str]],
        *,
        max_tokens: int,
        temperature: float,
        reasoning_effort: str,
        response_format: dict[str, Any] | None = None,
    ) -> str:
        payload: dict[str, Any] = {
            "model": self.model,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": max_tokens,
            "reasoning_effort": reasoning_effort,
        }
        if response_format is not None:
            payload["response_format"] = response_format
        response = self._request_json(
            f"{self.openai_url}/chat/completions", payload=payload
        )
        try:
            content = response["choices"][0]["message"]["content"]
        except (KeyError, IndexError, TypeError) as error:
            raise RuntimeError(f"Unexpected LLM response: {response!r}") from error
        if not isinstance(content, str):
            raise RuntimeError("The LLM response content was not text")
        return content

    def version(self) -> str:
        response = self._request_json(f"{self.root_url}/api/version")
        version = response.get("version")
        return version if isinstance(version, str) else "unknown"

    def installed_models(self) -> list[str]:
        response = self._request_json(f"{self.root_url}/api/tags")
        names = []
        for model in response.get("models", []):
            name = model.get("name") or model.get("model")
            if isinstance(name, str):
                names.append(name)
        return sorted(names)

    def running_models(self) -> list[str]:
        response = self._request_json(f"{self.root_url}/api/ps")
        names = []
        for model in response.get("models", []):
            name = model.get("name") or model.get("model")
            if isinstance(name, str):
                names.append(name)
        return sorted(names)

    def model_installed(self, model: str | None = None) -> bool:
        requested_model = model or self.model
        normalized_model = (
            requested_model if ":" in requested_model else f"{requested_model}:latest"
        )
        return normalized_model in self.installed_models()

    def pull_model(self, model: str | None = None) -> None:
        requested_model = model or self.model
        request = self._request(
            f"{self.root_url}/api/pull",
            payload={"model": requested_model, "stream": True},
        )
        try:
            with urlopen(request, timeout=max(self.timeout, 7200)) as response:
                last_status = ""
                for raw_line in response:
                    if not raw_line.strip():
                        continue
                    event = json.loads(raw_line)
                    if event.get("error"):
                        raise RuntimeError(str(event["error"]))
                    status = event.get("status", "")
                    completed = event.get("completed")
                    total = event.get("total")
                    if isinstance(completed, int) and isinstance(total, int) and total:
                        percent = completed * 100 // total
                        print(f"\r{status}: {percent:3d}%", end="", file=sys.stderr)
                    elif status and status != last_status:
                        print(status, file=sys.stderr)
                    last_status = status
                if last_status:
                    print(file=sys.stderr)
        except HTTPError as error:
            details = error.read().decode("utf-8", errors="replace")
            raise RuntimeError(
                f"Ollama returned HTTP {error.code}: {details}"
            ) from error
        except URLError as error:
            raise RuntimeError(f"Could not reach Ollama: {error.reason}") from error

    def _request_json(
        self, url: str, payload: dict[str, Any] | None = None
    ) -> dict[str, Any]:
        request = self._request(url, payload)
        try:
            with urlopen(request, timeout=self.timeout) as response:
                result = json.load(response)
        except HTTPError as error:
            details = error.read().decode("utf-8", errors="replace")
            raise RuntimeError(
                f"Ollama returned HTTP {error.code}: {details}"
            ) from error
        except URLError as error:
            raise RuntimeError(f"Could not reach Ollama: {error.reason}") from error
        if not isinstance(result, dict):
            raise RuntimeError(f"Unexpected Ollama response: {result!r}")
        return result

    @staticmethod
    def _request(url: str, payload: dict[str, Any] | None = None) -> Request:
        headers = {
            "Authorization": f"Bearer {os.environ.get('ANIX_LLM_API_KEY', 'no-key')}",
            "Content-Type": "application/json",
        }
        data = None if payload is None else json.dumps(payload).encode("utf-8")
        method = "GET" if data is None else "POST"
        return Request(url, data=data, headers=headers, method=method)
