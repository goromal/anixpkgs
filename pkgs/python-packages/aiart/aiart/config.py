"""Runtime configuration.

The NixOS module writes /etc/aiart/config.json; AIART_CONFIG points elsewhere
(tests, other hosts). Every key has a default so a partial file is fine.
"""
import json
import os
from dataclasses import dataclass, field

DEFAULT_PATH = "/etc/aiart/config.json"


@dataclass
class Config:
    projects_dirs: dict = field(default_factory=lambda: {
        "2d": "~/data/aiart",
        "3d": "~/data/3D",
    })
    cozy_url: str = "http://127.0.0.1:6262/cozy"
    cozy_token_file: str = "~/secrets/flask/cozy-api-token"
    comfy_url: str = "http://127.0.0.1:8188"
    comfy_models_dir: str = "/data/andrew/comfyui/models"
    cozy_input_dir: str = "/data/andrew/comfyui/input"
    backends: dict = field(default_factory=lambda: {
        "image": "imggen21",
        "edit": "imgedit4",
        "mesh": "hunyuan3d21",
    })
    workflow_dirs: list = field(default_factory=list)
    agents: list = field(default_factory=lambda: ["claude", "codex"])
    blender: str = "blender"
    image_viewer: str = "loupe"

    def path(self, key):
        return os.path.expanduser(getattr(self, key))

    def projects_dir(self, kind):
        return os.path.expanduser(self.projects_dirs[kind])


_KEYS = {
    "projectsDirs": "projects_dirs",
    "cozyUrl": "cozy_url",
    "cozyTokenFile": "cozy_token_file",
    "comfyUrl": "comfy_url",
    "comfyModelsDir": "comfy_models_dir",
    "cozyInputDir": "cozy_input_dir",
    "backends": "backends",
    "workflowDirs": "workflow_dirs",
    "agents": "agents",
    "blender": "blender",
    "imageViewer": "image_viewer",
}


def load(path=None):
    path = path or os.environ.get("AIART_CONFIG") or DEFAULT_PATH
    cfg = Config()
    try:
        with open(path) as f:
            raw = json.load(f)
    except FileNotFoundError:
        return cfg
    for key, attr in _KEYS.items():
        if key not in raw:
            continue
        if attr in ("backends", "projects_dirs"):
            setattr(cfg, attr, {**getattr(cfg, attr), **raw[key]})
        else:
            setattr(cfg, attr, raw[key])
    return cfg
