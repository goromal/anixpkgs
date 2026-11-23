# aiart

Agent-driven local art workflows for GPU machines. `aiart` opens a TUI that
lists art projects and launches Claude or Codex in one, and it provides the
commands those agents drive. Nothing calls a paid API: 2D jobs go through
cozy, 3D jobs go to ComfyUI, and Blender runs locally.

Enabled by the `aiArt` machine feature, which requires `gpu` and
`imageGeneration`. The agent guidance lives in two private skills,
`aiart-image` and `aiart-3d`, kept in `~/configs/private-skills/` and linked by
the module.

## Commands

```console
aiart                       # TUI: n new project, c/x open Claude/Codex, b Blender, v view image
aiart status                # services, backends, model readiness, live Blender (JSON)
aiart project new NAME --kind 2d|3d [--adopt]
aiart project info          # current project + journal tail

aiart image gen "PROMPT" [--width W --height H]
aiart image edit IN.png "INSTRUCTION" [--rect x,y,w,h]
aiart mesh gen [--image IN.png] [--prompt "..."] [--set steps=40 ...]
aiart models list | pull [WORKFLOW]

aiart blender open [file.blend|file.glb]   # Blender GUI with the live bridge
aiart blender exec FILE.py|-               # run bpy code in that Blender
aiart blender scene | import X.glb | save [P] | export P.glb | screenshot P.png
aiart blender render MODEL [--views front,iso,top] [--engine eevee|cycles|workbench]
aiart view [IMAGE]
```

Projects live in `services.aiart.projectsDirs`: 2D in `~/data/aiart`, 3D in
`~/data/3D` next to earlier 3D work. `--adopt` (and the TUI's new-project
dialog) turns an existing folder there into a project in place.

Generation commands print only the output path on stdout. Inside a project
they write `out/NNN-<slug>.<ext>`, repoint `latest.<ext>`, and append to
`journal.jsonl`.

## Backends

`/etc/aiart/config.json` (written by `services.aiart`) names a backend per task:

| task | default | runs on |
| --- | --- | --- |
| `image` | `imggen21` (Qwen-Image 2.1) | cozy queue |
| `edit` | `imgedit4` (Flux.2 dev turbo) | cozy queue |
| `mesh` | `hunyuan3d21` (Hunyuan3D 2.1 shape) | ComfyUI directly |

`image` and `edit` name cozy workflows, so they must be in
`services.comfyui.cozy.workflows`. `mesh` names an aiart mesh workflow:
either a bundled one (`aiart/workflows/`) or a `<name>.api.json` file in a
`workflowDirs` directory (default `~/data/aiart/workflows`), which overrides a
bundled file of the same name.

### Mesh workflow format

A ComfyUI API-format graph with an `_aiart` header:

```json
{
  "_aiart": {
    "kind": "mesh",
    "title": "shown in aiart status",
    "min_vram_gb": 4,
    "image_node": "2",            // LoadImage node fed the input image
    "save_node": "10",            // SaveGLB node whose "3d" output is fetched
    "params": {"steps": ["7", "steps"]},   // --set key -> [node, input]
    "models": [{"dir": "checkpoints", "name": "...", "url": "...", "bytes": 0}]
  },
  "1": {"class_type": "...", "inputs": {}}
}
```

To adopt a newer model (for example TRELLIS.2 on a bigger GPU), export its
ComfyUI workflow in API format, add the header, drop it in
`~/data/aiart/workflows/`, run `aiart models pull <name>`, then set
`services.aiart.backends.mesh`.

## Live Blender bridge

`aiart blender open` starts Blender with `blender_scripts/bridge.py`. The
bridge listens on a random loopback port and writes the port and a session
token to `$XDG_RUNTIME_DIR/aiart-blender.json` (mode 0600). Requests run on
Blender's main thread through a timer, so the user can keep working in the
same window while an agent edits the scene.
