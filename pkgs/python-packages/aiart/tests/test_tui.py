import asyncio

from textual.widgets import DataTable, Input

from aiart import projects
from aiart.config import Config
from aiart.tui import AiArtApp


def test_tui_creates_project_from_dialog(tmp_path):
    projects.create(tmp_path, "existing", "2d")
    cfg = Config(projects_dir=str(tmp_path), agents=["claude"])

    async def drive():
        app = AiArtApp(cfg)
        async with app.run_test() as pilot:
            assert app.query_one(DataTable).row_count == 1
            await pilot.press("n")
            await pilot.pause()
            app.screen.query_one("#name", Input).value = "castle"
            await pilot.click("#create")
            await pilot.pause()
            assert app.query_one(DataTable).row_count == 2

    asyncio.run(drive())
    assert {p.name: p.kind for p in projects.list_projects(tmp_path)} == {
        "existing": "2d", "castle": "3d"}
