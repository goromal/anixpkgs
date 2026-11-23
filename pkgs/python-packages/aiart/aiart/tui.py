"""Project picker. Launching an agent suspends the TUI and runs the agent CLI
in the project directory; quitting the agent comes back here."""
import datetime
import os
import shutil
import subprocess

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal, Vertical
from textual.screen import ModalScreen
from textual.widgets import (Button, DataTable, Footer, Header, Input, Label,
                             RadioButton, RadioSet, Static)

from . import blender, projects

SKILLS = {"2d": "aiart-image", "3d": "aiart-3d"}


def opening_prompt(project):
    return (
        "You are working in the aiart %s project '%s' at %s. Use the %s skill. "
        "Run `aiart project info` to see what has been done so far, look at the "
        "latest outputs, then ask me what I would like to make or change."
        % (project.kind.upper(), project.name, project.root, SKILLS[project.kind]))


def agent_command(agent, project):
    return [agent, opening_prompt(project)]


class NewProject(ModalScreen):
    CSS = """
    NewProject { align: center middle; }
    #dialog { width: 64; height: auto; padding: 1 2; border: thick $accent; background: $surface; }
    #dialog Input { margin-bottom: 1; }
    #error { color: $error; }
    #buttons { height: auto; align-horizontal: right; }
    """

    def __init__(self, projects_dir):
        super().__init__()
        self.projects_dir = projects_dir

    def compose(self) -> ComposeResult:
        with Vertical(id="dialog"):
            yield Label("New project")
            yield Input(placeholder="name (letters, digits, . _ -)", id="name")
            yield Input(placeholder="what is it? (optional)", id="description")
            with RadioSet(id="kind"):
                yield RadioButton("3D model (Blender)", value=True, id="k3d")
                yield RadioButton("2D image / painting", id="k2d")
            yield Static("", id="error")
            with Horizontal(id="buttons"):
                yield Button("Cancel", id="cancel")
                yield Button("Create", variant="primary", id="create")

    def on_button_pressed(self, event):
        if event.button.id == "cancel":
            self.dismiss(None)
        else:
            self._create()

    def on_input_submitted(self, event):
        self._create()

    def _create(self):
        kind = "3d" if self.query_one("#k3d", RadioButton).value else "2d"
        try:
            p = projects.create(self.projects_dir, self.query_one("#name", Input).value.strip(),
                                kind, self.query_one("#description", Input).value.strip())
        except projects.ProjectError as e:
            self.query_one("#error", Static).update(str(e))
            return
        self.dismiss(p)


class AiArtApp(App):
    TITLE = "aiart"
    CSS = """
    #table { width: 3fr; }
    #detail { width: 2fr; padding: 0 1; border-left: solid $accent; }
    """

    def __init__(self, cfg):
        super().__init__()
        self.cfg = cfg
        self.rows = []
        self.agents = available_agents(cfg)

    BINDINGS = [
        Binding("n", "new", "new project"),
        Binding("b", "blender", "Blender"),
        Binding("v", "view", "view image"),
        Binding("r", "refresh", "refresh"),
        Binding("q", "quit", "quit"),
    ]

    def compose(self) -> ComposeResult:
        yield Header()
        with Horizontal():
            yield DataTable(id="table", cursor_type="row", zebra_stripes=True)
            yield Static("", id="detail")
        yield Footer()

    def on_mount(self):
        table = self.query_one(DataTable)
        table.add_columns("project", "kind", "outputs", "updated")
        self.action_refresh()

    def action_refresh(self):
        table = self.query_one(DataTable)
        table.clear()
        self.rows = projects.list_projects(self.cfg.projects_dir)
        for p in self.rows:
            when = datetime.datetime.fromtimestamp(p.modified()).strftime("%Y-%m-%d %H:%M")
            table.add_row(p.name, p.kind, str(len(p.journal())), when)
        if not self.rows:
            self.query_one("#detail", Static).update(
                "No projects yet in %s.\n\nPress n to create one." % self.cfg.path("projects_dir"))
        else:
            self._show(0)

    def _current(self):
        if not self.rows:
            return None
        return self.rows[min(self.query_one(DataTable).cursor_row, len(self.rows) - 1)]

    def _show(self, idx):
        p = self.rows[idx]
        lines = ["[b]%s[/b]  (%s)" % (p.name, p.kind), p.meta.get("description") or "", p.root, ""]
        for e in p.journal()[-8:][::-1]:
            what = e.get("prompt") or os.path.basename(e.get("source") or "")
            lines.append("%s  %s  %s" % (e["at"][5:16], e["action"], (what or "")[:60]))
        self.query_one("#detail", Static).update("\n".join(lines))

    def on_data_table_row_highlighted(self, event):
        if self.rows:
            self._show(event.cursor_row)

    def on_data_table_row_selected(self, event):
        if self.agents:
            self.action_agent(self.agents[0])

    def action_new(self):
        def created(p):
            if p:
                self.action_refresh()
        self.push_screen(NewProject(self.cfg.projects_dir), created)

    def action_agent(self, agent):
        p = self._current()
        if not p:
            return
        with self.suspend():
            subprocess.run(agent_command(agent, p), cwd=p.root)
        self.action_refresh()

    def action_blender(self):
        p = self._current()
        if not p:
            return
        blends = sorted((f for f in os.listdir(p.root) if f.endswith(".blend")),
                        key=lambda f: os.path.getmtime(os.path.join(p.root, f)))
        target = os.path.join(p.root, blends[-1]) if blends else None
        if not target and os.path.exists(os.path.join(p.root, "latest.glb")):
            target = os.path.join(p.root, "latest.glb")
        blender.open_gui(self.cfg.blender, target)
        self.notify("Blender starting with the live bridge")

    def action_view(self):
        p = self._current()
        latest = p and os.path.join(p.root, "latest.png")
        if not latest or not os.path.exists(latest):
            self.notify("no image in this project yet", severity="warning")
            return
        subprocess.Popen([self.cfg.image_viewer, latest], start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


AGENT_KEYS = ("c", "x")


def available_agents(cfg):
    return [a for a in cfg.agents if shutil.which(a)] or list(cfg.agents)


def run(cfg):
    agents = available_agents(cfg)[:len(AGENT_KEYS)]
    bindings = [Binding(k, "agent(%r)" % a, a) for k, a in zip(AGENT_KEYS, agents)]
    app_cls = type("AiArt", (AiArtApp,), {"BINDINGS": bindings + AiArtApp.BINDINGS})
    app_cls(cfg).run()
