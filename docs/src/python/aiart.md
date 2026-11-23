# aiart

Agent-driven local 2D and 3D art workflows

A TUI that opens agent sessions per art project for 2D and 3D art.

## Usage

```bash
usage: aiart [-h] {tui,status,project,image,mesh,models,blender,view} ...

aiart command line. With no command it opens the TUI.

positional arguments:
  {tui,status,project,image,mesh,models,blender,view}
    tui                 project picker that launches agents (default)
    status              backends, services and live Blender as JSON
    project             create, list or describe projects
    image               2D generation and editing
    mesh                3D generation
    models              model weights for mesh workflows
    blender             live Blender bridge and headless renders
    view                open an image in the viewer (default latest.png)

options:
  -h, --help            show this help message and exit
```

