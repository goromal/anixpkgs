"""Google Photorealistic 3D Tiles client (stdlib only; no bpy).

Selects the tiles covering a vertical cylinder around a lat/lon, downloads their
GLBs, and rewrites each GLB's root node transforms so that the geometry lands in
a local East-North-Up (ENU) frame centered on the target. Doing that rewrite in
float64 here (rather than letting Blender apply ECEF-sized transforms in float32)
avoids ~0.5 m precision jitter and seams between tiles.

Terms of use: Google's Map Tiles API policies forbid pre-fetching / caching
content and deriving 3D objects from the tiles. Downloads go to a temporary
directory that the caller deletes as soon as the tiles are imported.
"""

import concurrent.futures
import http.client
import json
import math
import os
import struct
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter

ROOT_URL = "https://tile.googleapis.com/v1/3dtiles/root.json"

# WGS84
_A = 6378137.0
_F = 1.0 / 298.257223563
_E2 = _F * (2.0 - _F)

# Vertical extent (meters relative to the target point) considered when culling
# tiles: covers the Dead Sea to above Everest relative to a sea-level target.
Z_MIN = -1000.0
Z_MAX = 9000.0


class TilesError(RuntimeError):
    pass


class Cancelled(TilesError):
    def __init__(self):
        super().__init__("Cancelled")


def _check(cancel):
    if cancel is not None and cancel():
        raise Cancelled()


# ---------------------------------------------------------------------------
# 4x4 matrix helpers (row-major nested lists, float64)
# ---------------------------------------------------------------------------


def mat_identity():
    return [[1.0 if i == j else 0.0 for j in range(4)] for i in range(4)]


def mat_mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def mat_apply(m, p):
    return [m[i][0] * p[0] + m[i][1] * p[1] + m[i][2] * p[2] + m[i][3] for i in range(3)]


def mat_from_column_major(values):
    return [[float(values[j * 4 + i]) for j in range(4)] for i in range(4)]


def mat_to_column_major(m):
    return [m[i][j] for j in range(4) for i in range(4)]


def mat_from_trs(t=None, r=None, s=None):
    tx, ty, tz = t or (0.0, 0.0, 0.0)
    x, y, z, w = r or (0.0, 0.0, 0.0, 1.0)
    sx, sy, sz = s or (1.0, 1.0, 1.0)
    rot = [
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ]
    return [
        [rot[0][0] * sx, rot[0][1] * sy, rot[0][2] * sz, tx],
        [rot[1][0] * sx, rot[1][1] * sy, rot[1][2] * sz, ty],
        [rot[2][0] * sx, rot[2][1] * sy, rot[2][2] * sz, tz],
        [0.0, 0.0, 0.0, 1.0],
    ]


# glTF is Y-up; 3D Tiles (and Blender's glTF importer) rotate it to Z-up with
# (x, y, z) -> (x, -z, y).
Y_UP_TO_Z_UP = [
    [1.0, 0.0, 0.0, 0.0],
    [0.0, 0.0, -1.0, 0.0],
    [0.0, 1.0, 0.0, 0.0],
    [0.0, 0.0, 0.0, 1.0],
]
Z_UP_TO_Y_UP = [
    [1.0, 0.0, 0.0, 0.0],
    [0.0, 0.0, 1.0, 0.0],
    [0.0, -1.0, 0.0, 0.0],
    [0.0, 0.0, 0.0, 1.0],
]


# ---------------------------------------------------------------------------
# Geodesy
# ---------------------------------------------------------------------------


def lla_to_ecef(lat_deg, lon_deg, h=0.0):
    lat = math.radians(lat_deg)
    lon = math.radians(lon_deg)
    n = _A / math.sqrt(1.0 - _E2 * math.sin(lat) ** 2)
    return [
        (n + h) * math.cos(lat) * math.cos(lon),
        (n + h) * math.cos(lat) * math.sin(lon),
        (n * (1.0 - _E2) + h) * math.sin(lat),
    ]


def ecef_to_enu_matrix(lat_deg, lon_deg, h=0.0):
    """Rigid transform taking ECEF points to ENU coordinates about (lat, lon, h)."""
    lat = math.radians(lat_deg)
    lon = math.radians(lon_deg)
    east = [-math.sin(lon), math.cos(lon), 0.0]
    north = [-math.sin(lat) * math.cos(lon), -math.sin(lat) * math.sin(lon), math.cos(lat)]
    up = [math.cos(lat) * math.cos(lon), math.cos(lat) * math.sin(lon), math.sin(lat)]
    p0 = lla_to_ecef(lat_deg, lon_deg, h)
    rows = []
    for axis in (east, north, up):
        rows.append(axis + [-sum(a * p for a, p in zip(axis, p0))])
    rows.append([0.0, 0.0, 0.0, 1.0])
    return rows


def parse_location(text):
    """Parse 'lat, lon' (as copied from Google Maps) into floats."""
    parts = [p for p in text.replace(",", " ").split() if p]
    if len(parts) != 2:
        raise ValueError(f"Expected 'lat, lon', got {text!r}")
    lat, lon = float(parts[0]), float(parts[1])
    if not (-90.0 <= lat <= 90.0 and -180.0 <= lon <= 180.0):
        raise ValueError(f"Location out of range: {lat}, {lon}")
    return lat, lon


# ---------------------------------------------------------------------------
# Culling
# ---------------------------------------------------------------------------


def box_corners(box):
    c = box[0:3]
    axes = (box[3:6], box[6:9], box[9:12])
    corners = []
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            for sz in (-1.0, 1.0):
                corners.append(
                    [c[i] + sx * axes[0][i] + sy * axes[1][i] + sz * axes[2][i] for i in range(3)]
                )
    return corners


def box_intersects_cylinder(box, to_enu, radius):
    """Conservative test of an OBB (tileset frame) against the target cylinder.

    The OBB's corners are mapped into the ENU frame and their axis-aligned bounds
    are tested against a vertical cylinder of `radius` spanning [Z_MIN, Z_MAX].
    """
    pts = [mat_apply(to_enu, p) for p in box_corners(box)]
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    zs = [p[2] for p in pts]
    if max(zs) < Z_MIN or min(zs) > Z_MAX:
        return False
    dx = max(min(xs) - 0.0, 0.0, 0.0 - max(xs))
    dy = max(min(ys) - 0.0, 0.0, 0.0 - max(ys))
    return dx * dx + dy * dy <= radius * radius


def volume_intersects(volume, to_enu, radius):
    if "box" in volume:
        return box_intersects_cylinder(volume["box"], to_enu, radius)
    # Regions/spheres are not used by Google's tileset; keep them conservatively.
    return True


# ---------------------------------------------------------------------------
# HTTP
# ---------------------------------------------------------------------------


class Client:
    """Carries the API key and the session token across tile requests.

    Only the root.json request is billable; the session it returns covers
    renderer tile requests for about three hours.
    """

    # Seconds without progress on a socket before a request is retried. Google
    # occasionally leaves a connection unanswered; fail fast and reconnect.
    TIMEOUT = 15.0

    def __init__(self, key, opener=None, retries=3, cancel=None, on_retry=None, backoff=1.0):
        if not key:
            raise TilesError("No Google Map Tiles API key provided")
        self.key = key
        self.session = None
        self.retries = retries
        self.backoff = backoff
        self.cancel = cancel
        self.on_retry = on_retry  # on_retry(reason) before each retry
        self._opener = opener or urllib.request.urlopen
        self.requests = 0

    def url(self, uri, base=ROOT_URL):
        full = urllib.parse.urljoin(base, uri)
        parsed = urllib.parse.urlparse(full)
        query = dict(urllib.parse.parse_qsl(parsed.query))
        if "session" in query and self.session is None:
            self.session = query["session"]
        query.setdefault("key", self.key)
        # root.json rejects a session parameter (HTTP 400); it starts a new session.
        if self.session is not None and parsed.path != urllib.parse.urlparse(ROOT_URL).path:
            query.setdefault("session", self.session)
        return urllib.parse.urlunparse(parsed._replace(query=urllib.parse.urlencode(query)))

    def get(self, url):
        delay = self.backoff
        for attempt in range(self.retries + 1):
            _check(self.cancel)
            try:
                self.requests += 1
                with self._opener(url, timeout=self.TIMEOUT) as resp:
                    return resp.read()
            except urllib.error.HTTPError as e:
                retryable = e.code == 429 or e.code >= 500
                if not retryable or attempt == self.retries:
                    body = e.read().decode("utf-8", "replace")[:500]
                    raise TilesError(f"HTTP {e.code} for {_redact(url)}: {body}") from e
                reason = f"HTTP {e.code}"
            except (OSError, http.client.HTTPException) as e:  # URLError, timeouts, resets
                if attempt == self.retries:
                    raise TilesError(f"Request failed for {_redact(url)}: {e}") from e
                reason = str(getattr(e, "reason", e)) or type(e).__name__
            if self.on_retry is not None:
                self.on_retry(reason)
            # Wake early on cancel rather than sleeping out the backoff.
            deadline = time.monotonic() + delay
            while time.monotonic() < deadline:
                _check(self.cancel)
                time.sleep(max(0.0, min(0.1, deadline - time.monotonic())))
            delay *= 2.0
        raise AssertionError("unreachable")

    def get_json(self, url):
        return json.loads(self.get(url))


def _redact(url):
    parsed = urllib.parse.urlparse(url)
    query = [(k, "***" if k == "key" else v) for k, v in urllib.parse.parse_qsl(parsed.query)]
    return urllib.parse.urlunparse(parsed._replace(query=urllib.parse.urlencode(query)))


# ---------------------------------------------------------------------------
# Tile selection
# ---------------------------------------------------------------------------


class TileRef:
    def __init__(self, url, transform, geometric_error):
        self.url = url
        self.transform = transform  # tileset frame (Z-up, ECEF) from tile content frame
        self.geometric_error = geometric_error


def select_tiles(client, lat, lon, radius, max_error, max_tiles=2000, progress=None, cancel=None, workers=8):
    """Walk the tileset and return the GLB tiles covering the target cylinder.

    Descends (REPLACE refinement) until a tile's geometricError is <= max_error
    or it has no children. Calls progress(n_selected, n_to_visit) after each
    level; raises Cancelled once cancel() returns true.
    """
    to_enu = ecef_to_enu_matrix(lat, lon)
    root_url = client.url(ROOT_URL)
    tileset = client.get_json(root_url)
    # frontier entries: (tile json, base url for relative uris, parent transform)
    frontier = [(tileset["root"], root_url, mat_identity())]
    selected = []

    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        while frontier:
            _check(cancel)
            next_frontier = []
            pending = []  # external tilesets to fetch: (url, transform)
            for tile, base, parent_tf in frontier:
                tf = parent_tf
                if "transform" in tile:
                    tf = mat_mul(parent_tf, mat_from_column_major(tile["transform"]))
                if not volume_intersects(tile["boundingVolume"], mat_mul(to_enu, tf), radius):
                    continue
                children = tile.get("children") or []
                content = tile.get("content") or {}
                uri = content.get("uri") or content.get("url")
                error = float(tile.get("geometricError", 0.0))
                if uri and _is_tileset(uri):
                    pending.append((client.url(uri, base), tf))
                    for child in children:
                        next_frontier.append((child, base, tf))
                elif children and (error > max_error or not uri):
                    for child in children:
                        next_frontier.append((child, base, tf))
                elif uri:
                    selected.append(TileRef(client.url(uri, base), tf, error))
                    if len(selected) > max_tiles:
                        raise TilesError(
                            f"More than {max_tiles} tiles selected; "
                            "reduce the radius or raise max_error"
                        )
            def fetch(p):
                _check(cancel)
                return client.get_json(p[0])

            for (url, tf), sub in zip(pending, pool.map(fetch, pending)):
                next_frontier.append((sub["root"], url, tf))
            if progress:
                progress(len(selected), len(next_frontier))
            frontier = next_frontier
    return selected


def _is_tileset(uri):
    return urllib.parse.urlparse(uri).path.endswith(".json")


# ---------------------------------------------------------------------------
# GLB rewriting
# ---------------------------------------------------------------------------

_GLB_MAGIC = 0x46546C67
_CHUNK_JSON = 0x4E4F534A


def read_glb(data):
    magic, version, length = struct.unpack_from("<III", data, 0)
    if magic != _GLB_MAGIC or version != 2:
        raise TilesError("Not a glTF 2.0 GLB")
    chunk_len, chunk_type = struct.unpack_from("<II", data, 12)
    if chunk_type != _CHUNK_JSON:
        raise TilesError("GLB first chunk is not JSON")
    doc = json.loads(data[20 : 20 + chunk_len].decode("utf-8"))
    rest = data[20 + chunk_len : length]
    return doc, rest


def write_glb(doc, rest):
    payload = json.dumps(doc, separators=(",", ":")).encode("utf-8")
    payload += b" " * (-len(payload) % 4)
    total = 12 + 8 + len(payload) + len(rest)
    return struct.pack("<III", _GLB_MAGIC, 2, total) + struct.pack("<II", len(payload), _CHUNK_JSON) + payload + rest


def relocate_glb(data, world_to_local):
    """Bake `world_to_local` (Z-up) into the GLB's scene root nodes.

    Returns (new GLB bytes, asset.copyright or "").
    """
    doc, rest = read_glb(data)
    rtc = (doc.get("extensions") or {}).get("CESIUM_RTC", {}).get("center")
    if rtc:
        rtc_tf = mat_from_trs(t=rtc)
        world_to_local = mat_mul(world_to_local, rtc_tf)
        doc["extensions"].pop("CESIUM_RTC")
        used = doc.get("extensionsUsed") or []
        if "CESIUM_RTC" in used:
            used.remove("CESIUM_RTC")
    # In glTF (Y-up) space: Z_UP_TO_Y_UP * world_to_local * Y_UP_TO_Z_UP; the
    # importer's own Y-up -> Z-up conversion then yields world_to_local * (Z-up).
    pre = mat_mul(Z_UP_TO_Y_UP, mat_mul(world_to_local, Y_UP_TO_Z_UP))
    nodes = doc.get("nodes") or []
    roots = set()
    for scene in doc.get("scenes") or []:
        roots.update(scene.get("nodes") or [])
    for idx in sorted(roots):
        node = nodes[idx]
        if "matrix" in node:
            local = mat_from_column_major(node.pop("matrix"))
        else:
            local = mat_from_trs(node.pop("translation", None), node.pop("rotation", None), node.pop("scale", None))
        node["matrix"] = mat_to_column_major(mat_mul(pre, local))
    copyright_text = (doc.get("asset") or {}).get("copyright", "")
    return write_glb(doc, rest), copyright_text


def download_tiles(client, refs, lat, lon, out_dir, progress=None, cancel=None, workers=8):
    """Download and relocate tiles into out_dir. Returns (paths, Counter of copyrights).

    Calls progress(n_done, n_total) after each tile; raises Cancelled once
    cancel() returns true.
    """
    to_enu = ecef_to_enu_matrix(lat, lon)
    copyrights = Counter()
    paths = []

    def fetch(item):
        i, ref = item
        _check(cancel)
        data, text = relocate_glb(client.get(ref.url), mat_mul(to_enu, ref.transform))
        path = os.path.join(out_dir, f"tile_{i:05d}.glb")
        with open(path, "wb") as f:
            f.write(data)
        return path, text

    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        for n, (path, text) in enumerate(pool.map(fetch, enumerate(refs)), 1):
            paths.append(path)
            for part in text.split(";"):
                if part.strip():
                    copyrights[part.strip()] += 1
            if progress:
                progress(n, len(refs))
    return paths, copyrights


def attribution(copyrights):
    """Google's required attribution: sources ordered by frequency of occurrence."""
    return "; ".join(name for name, _ in copyrights.most_common())


# ---------------------------------------------------------------------------
# API key lookup
# ---------------------------------------------------------------------------

DEFAULT_KEY_FILE = "~/secrets/google/maps.json"
KEY_ENV = "GOOGLE_MAP_TILES_API_KEY"


def resolve_key(explicit="", key_file=DEFAULT_KEY_FILE):
    if os.environ.get(KEY_ENV):
        return os.environ[KEY_ENV].strip()
    if explicit:
        return explicit.strip()
    path = os.path.expanduser(key_file or DEFAULT_KEY_FILE)
    if os.path.isfile(path):
        with open(path) as f:
            text = f.read().strip()
        if text.startswith("{"):
            try:
                return json.loads(text)["key"].strip()
            except (ValueError, KeyError, AttributeError) as e:
                raise TilesError(f"{path}: expected a JSON object with a 'key' string") from e
        return text
    raise TilesError(f"No API key: set ${KEY_ENV}, the add-on preference, or create {path}")
