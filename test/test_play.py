"""Run with PLAY_SCRIPT pointing to a built play/bin/play.

Only emulator binaries and rcrsync are replaced. The generated launcher's
argument handling, locking, save copies, signal handling and recovery run intact.
"""
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time

import pytest


@pytest.fixture
def session(tmp_path):
    home = tmp_path / "home with spaces"
    home.mkdir()
    (home / "games").mkdir()
    (home / "more-games").mkdir()
    for name in ("kingdomheartsii.chd", "jakii.chd", "jak3.chd"):
        (home / "more-games" / name).touch()
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    emulator = bin_dir / "emulator"
    emulator.write_text(f"#!{sys.executable}\n" + r'''
import json, os, signal, sys, time
from pathlib import Path
home = Path(os.environ["HOME"])
(home / "argv.json").write_text(json.dumps(sys.argv[1:]))
card = home / ".config/PCSX2/memcards/Mcd001.ps2"
if "-e" in sys.argv:
    card = home / ".local/share/dolphin-emu/GC/MemoryCardA.USA.raw"
if os.environ.get("CARD_PATH"):
    card = Path(os.environ["CARD_PATH"])
if os.environ.get("CHANGE_CARD_PATH"):
    card = home / ".config/PCSX2/new cards/Mcd001.ps2"
    ini = home / ".config/PCSX2/inis"
    ini.mkdir(parents=True, exist_ok=True)
    (ini / "PCSX2.ini").write_text("[Folders]\nMemoryCards = new cards\n")
if "EXPECT_CARD" in os.environ:
    assert card.read_text() == os.environ["EXPECT_CARD"]
card.parent.mkdir(parents=True, exist_ok=True)
def save(*args):
    card.write_text("saved progress")
    raise SystemExit(int(os.environ.get("EMU_EXIT", "0")))
signal.signal(signal.SIGTERM, save)
(home / "ready").touch()
if os.environ.get("WAIT_FOR_STOP"):
    while True:
        time.sleep(0.02)
save()
''')
    emulator.chmod(0o755)
    sync = bin_dir / "rcrsync"
    sync.write_text(f"#!{sys.executable}\n" + '''
import os, sys
from pathlib import Path
log = Path(os.environ["HOME"]) / "sync.log"
with log.open("a") as f:
    f.write(" ".join(sys.argv[1:]) + "\\n")
count = len(log.read_text().splitlines())
if count == int(os.environ.get("FAIL_SYNC", "0")):
    sys.exit(1)
''')
    sync.chmod(0o755)
    source = Path(os.environ["PLAY_SCRIPT"]).read_text()
    source, count = re.subn(r"/nix/store/[^/\s]+/bin/(?:pcsx2-qt|dolphin-emu)", str(emulator), source)
    assert count == 2
    launcher = bin_dir / "play"
    launcher.write_text(source)
    launcher.chmod(0o755)
    env = {**os.environ, "HOME": str(home), "PATH": f"{bin_dir}:{os.environ['PATH']}",
           "XDG_CONFIG_HOME": str(home / ".config"), "XDG_STATE_HOME": str(home / ".local/state")}
    return home, launcher, env


def run(session, game, **extra):
    home, launcher, env = session
    return subprocess.run([launcher, game], env={**env, **extra}, capture_output=True, text=True, timeout=10)


def wait_ready(home, process):
    deadline = time.monotonic() + 5
    while not (home / "ready").exists():
        assert process.poll() is None
        assert time.monotonic() < deadline
        time.sleep(0.02)


@pytest.mark.parametrize("alias,filename", [("kh2", "kingdomheartsii"), ("jak2", "jakii"), ("jak3", "jak3")])
def test_ps2_aliases_and_first_card(session, alias, filename):
    home, _, _ = session
    result = run(session, alias)
    assert result.returncode == 0, result.stdout + result.stderr
    assert json.loads((home / "argv.json").read_text()) == ["-fullscreen", "-batch", "--", str(home / f"more-games/{filename}.chd")]
    assert (home / "games/ps2/memcards/Mcd001.ps2").read_text() == "saved progress"
    assert (home / "sync.log").read_text().splitlines() == ["sync games2", "sync games", "sync games"]
    assert not (home / ".local/state/play/pcsx2.pending").exists()


def test_restores_card_and_keeps_backup(session):
    home, _, _ = session
    cloud = home / "games/ps2/memcards"
    cloud.mkdir(parents=True)
    (cloud / "Mcd001.ps2").write_text("cloud progress")
    local = home / ".config/PCSX2/memcards"
    local.mkdir(parents=True)
    (local / "Mcd001.ps2").write_text("previous local")
    result = run(session, "jak2", EXPECT_CARD="cloud progress")
    assert result.returncode == 0, result.stdout + result.stderr
    assert (local.with_name("memcards.bak") / "Mcd001.ps2").read_text() == "previous local"
    assert (cloud.with_name("memcards.bak") / "Mcd001.ps2").read_text() == "cloud progress"


def test_dolphin_still_syncs(session):
    home, _, _ = session
    (home / "games/LegendOfZeldaCollectorsEdition.iso").touch()
    (home / "games/MemoryCardA.USA.raw").write_text("dolphin progress")
    result = run(session, "zelda", EXPECT_CARD="dolphin progress")
    assert result.returncode == 0, result.stdout + result.stderr
    assert json.loads((home / "argv.json").read_text()) == ["-a", "LLE", "-e", str(home / "games/LegendOfZeldaCollectorsEdition.iso")]
    assert (home / "games/MemoryCardA.USA.raw").read_text() == "saved progress"


@pytest.mark.parametrize("failure", ["1", "2"])
def test_sync_failure_prevents_launch(session, failure):
    home, _, _ = session
    assert run(session, "kh2", FAIL_SYNC=failure).returncode != 0
    assert not (home / "ready").exists()


def test_upload_failure_preserves_cards_and_blocks_stale_restore(session):
    home, _, _ = session
    assert run(session, "kh2", FAIL_SYNC="3").returncode != 0
    assert (home / "games/ps2/memcards/Mcd001.ps2").read_text() == "saved progress"
    assert (home / ".local/state/play/pcsx2.pending").exists()
    (home / "ready").unlink()
    result = run(session, "kh2")
    assert result.returncode != 0
    assert "Previous save transfer was interrupted" in result.stdout
    assert not (home / "ready").exists()


def test_setup_uses_configured_card_directory(session):
    home, _, _ = session
    ini = home / ".config/PCSX2/inis"
    ini.mkdir(parents=True)
    (ini / "PCSX2.ini").write_text("[Folders]\nMemoryCards = custom cards\n")
    card = home / ".config/PCSX2/custom cards/Mcd001.ps2"
    result = run(session, "setup-ps2", CARD_PATH=str(card))
    assert result.returncode == 0, result.stdout + result.stderr
    assert json.loads((home / "argv.json").read_text()) == []
    assert (home / "games/ps2/memcards/Mcd001.ps2").read_text() == "saved progress"


@pytest.mark.parametrize("stop_group", [False, True])
def test_shutdown_waits_for_cards_and_upload(session, stop_group):
    home, launcher, env = session
    process = subprocess.Popen([launcher, "jak2"], env={**env, "WAIT_FOR_STOP": "1"}, start_new_session=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    try:
        wait_ready(home, process)
        # The local session lock must reject a second game before any sync.
        assert run(session, "kh2").returncode != 0
        if stop_group:
            os.killpg(process.pid, signal.SIGTERM)
        else:
            process.terminate()
        output = process.communicate(timeout=5)[0]
        assert process.returncode == 0, output
        assert (home / "games/ps2/memcards/Mcd001.ps2").read_text() == "saved progress"
        assert (home / "sync.log").read_text().splitlines()[-1] == "sync games"
        assert not (home / ".local/state/play/pcsx2.pending").exists()
    finally:
        if process.poll() is None:
            process.terminate()
            process.communicate(timeout=5)


def test_emulator_failure_still_copies_cards_and_preserves_exit_status(session):
    home, _, _ = session
    assert run(session, "kh2", EMU_EXIT="7").returncode == 7
    assert (home / "games/ps2/memcards/Mcd001.ps2").read_text() == "saved progress"


def test_invalid_game_does_not_sync(session):
    home, _, _ = session
    assert run(session, "unknown").returncode != 0
    assert not (home / "sync.log").exists()


def test_setup_recovery_tracks_changed_card_directory(session):
    home, _, _ = session
    result = run(session, "setup-ps2", CHANGE_CARD_PATH="1", FAIL_SYNC="2")
    assert result.returncode != 0
    marker = (home / ".local/state/play/pcsx2.pending").read_text()
    assert str(home / ".config/PCSX2/new cards") in marker
    assert (home / "games/ps2/memcards/Mcd001.ps2").read_text() == "saved progress"
