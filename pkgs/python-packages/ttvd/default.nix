{
  buildPythonPackage,
  setuptools,
  pkg-src,
  aiofiles,
  aiosqlite,
  emoji,
  fastapi,
  gmssl,
  httpx,
  lxml,
  openpyxl,
  pydantic,
  pyperclip,
  qrcode,
  rich,
  uvicorn,
  ffmpeg-headless,
  python,
}:
let
  pythonLibDir = "lib/python${python.passthru.pythonVersion}/site-packages";
in
buildPythonPackage rec {
  pname = "ttvd";
  version = "5.8";
  format = "setuptools";
  src = pkg-src;

  nativeBuildInputs = [ setuptools ];

  prePatch = ''
    # Remove the existing pyproject.toml so setuptools uses our setup.py cleanly
    rm -f pyproject.toml uv.lock

    # Add __init__.py to src so find_packages picks it up
    touch src/__init__.py

    # Patch PROJECT_ROOT to use XDG_DATA_HOME instead of the read-only nix store
    substituteInPlace src/custom/internal.py \
      --replace-fail \
        'PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent.joinpath("Volume")' \
        'import os; PROJECT_ROOT = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share")) / "TikTokDownloader"'
    substituteInPlace src/custom/internal.py \
      --replace-fail \
        'PROJECT_ROOT.mkdir(exist_ok=True)' \
        'PROJECT_ROOT.mkdir(parents=True, exist_ok=True)'

    # Inject a setup.py that declares src.* packages and a ttvd entry point
    cat > setup.py <<'SETUP'
from setuptools import setup, find_packages
setup(
    name='ttvd',
    version='5.8',
    packages=find_packages(include=['src', 'src.*']),
    py_modules=['ttvd_entry'],
    entry_points={
        'console_scripts': ['ttvd = ttvd_entry:run_main'],
    },
)
SETUP

    # Synchronous entry point that wraps the async main
    cat > ttvd_entry.py <<'ENTRY'
from asyncio import run, CancelledError
from src.application import TikTokDownloader

async def _main():
    async with TikTokDownloader() as d:
        await d.run()

def run_main():
    try:
        run(_main())
    except (KeyboardInterrupt, CancelledError):
        pass
ENTRY
  '';

  makeWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    "${ffmpeg-headless}/bin"
  ];

  propagatedBuildInputs = [
    aiofiles
    aiosqlite
    emoji
    fastapi
    gmssl
    httpx
    lxml
    openpyxl
    pydantic
    pyperclip
    qrcode
    rich
    uvicorn
  ];

  doCheck = false;

  meta = {
    description = "TikTok and Douyin video downloader CLI";
    longDescription = ''
      CLI wrapper for JoeanAmier/TikTokDownloader. Supports downloading
      TikTok and Douyin videos, image sets, music, and live streams.
      Available on recreational machines.
    '';
    autoGenUsageCmd = null;
  };
}
