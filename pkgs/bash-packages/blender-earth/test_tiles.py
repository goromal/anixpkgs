import io
import json
import os
import tempfile
import unittest
import urllib.parse
from collections import Counter

from earth_tiles import tiles

LAT, LON = 40.748440, -73.985664


def box_around(lat, lon, half, h=0.0):
    """OBB (ECEF) of half-size `half` meters aligned with the local ENU axes."""
    enu = tiles.ecef_to_enu_matrix(lat, lon)
    c = tiles.lla_to_ecef(lat, lon, h)
    axes = [[enu[r][i] * half for i in range(3)] for r in range(3)]
    return c + axes[0] + axes[1] + axes[2]


def make_glb(translation, copyright_text):
    doc = {
        "asset": {"version": "2.0", "copyright": copyright_text},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"translation": translation}],
    }
    return tiles.write_glb(doc, b"")


class FakeResponse(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


class FakeServer:
    def __init__(self, routes):
        self.routes = routes
        self.seen = []

    def __call__(self, url, timeout=None):
        parsed = urllib.parse.urlparse(url)
        self.seen.append(dict(urllib.parse.parse_qsl(parsed.query)))
        return FakeResponse(self.routes[parsed.path])


def fake_tileset():
    near = box_around(LAT, LON, 100.0)
    far = box_around(LAT + 1.0, LON, 100.0)
    big = box_around(LAT, LON, 5000.0)
    root = {
        "asset": {"version": "1.0"},
        "root": {
            "boundingVolume": {"box": big},
            "geometricError": 1000.0,
            "children": [
                {
                    "boundingVolume": {"box": big},
                    "geometricError": 500.0,
                    "content": {"uri": "/v1/3dtiles/datasets/x/files/sub.json?session=S1"},
                }
            ],
        },
    }
    sub = {
        "root": {
            "boundingVolume": {"box": big},
            "geometricError": 100.0,
            "content": {"uri": "coarse.glb"},
            "children": [
                {"boundingVolume": {"box": near}, "geometricError": 2.0, "content": {"uri": "near.glb"}},
                {"boundingVolume": {"box": far}, "geometricError": 2.0, "content": {"uri": "far.glb"}},
            ],
        }
    }
    ecef = tiles.lla_to_ecef(LAT, LON)
    # glTF is Y-up: ECEF (x, y, z) is stored as (x, z, -y).
    yup = [ecef[0], ecef[2], -ecef[1]]
    return {
        "/v1/3dtiles/root.json": json.dumps(root).encode(),
        "/v1/3dtiles/datasets/x/files/sub.json": json.dumps(sub).encode(),
        "/v1/3dtiles/datasets/x/files/near.glb": make_glb(yup, "Data A;Data B"),
        "/v1/3dtiles/datasets/x/files/coarse.glb": make_glb(yup, "Data B"),
        "/v1/3dtiles/datasets/x/files/far.glb": make_glb(yup, "Data C"),
    }


class GeodesyTest(unittest.TestCase):
    def test_target_maps_to_origin(self):
        m = tiles.ecef_to_enu_matrix(LAT, LON)
        p = tiles.mat_apply(m, tiles.lla_to_ecef(LAT, LON))
        for v in p:
            self.assertAlmostEqual(v, 0.0, places=6)

    def test_height_maps_to_up(self):
        m = tiles.ecef_to_enu_matrix(LAT, LON)
        p = tiles.mat_apply(m, tiles.lla_to_ecef(LAT, LON, 50.0))
        self.assertAlmostEqual(p[0], 0.0, places=6)
        self.assertAlmostEqual(p[1], 0.0, places=6)
        self.assertAlmostEqual(p[2], 50.0, places=6)

    def test_parse_location(self):
        self.assertEqual(tiles.parse_location("40.5, -73.25"), (40.5, -73.25))
        self.assertEqual(tiles.parse_location(" 1 2 "), (1.0, 2.0))
        with self.assertRaises(ValueError):
            tiles.parse_location("91, 0")
        with self.assertRaises(ValueError):
            tiles.parse_location("1")


class CullingTest(unittest.TestCase):
    def test_cylinder(self):
        m = tiles.ecef_to_enu_matrix(LAT, LON)
        self.assertTrue(tiles.box_intersects_cylinder(box_around(LAT, LON, 10.0), m, 50.0))
        # ~111 km north: outside
        self.assertFalse(tiles.box_intersects_cylinder(box_around(LAT + 1.0, LON, 10.0), m, 50.0))
        # high above the target but within the vertical extent: inside
        self.assertTrue(tiles.box_intersects_cylinder(box_around(LAT, LON, 10.0, h=3000.0), m, 50.0))
        # far above the vertical extent: outside
        self.assertFalse(tiles.box_intersects_cylinder(box_around(LAT, LON, 10.0, h=20000.0), m, 50.0))


class TraversalTest(unittest.TestCase):
    def test_select_and_download(self):
        server = FakeServer(fake_tileset())
        client = tiles.Client("K", opener=server)
        refs = tiles.select_tiles(client, LAT, LON, radius=150.0, max_error=4.0)
        self.assertEqual([urllib.parse.urlparse(r.url).path for r in refs], ["/v1/3dtiles/datasets/x/files/near.glb"])
        # key on every request; session propagated after it first appears
        self.assertTrue(all(q.get("key") == "K" for q in server.seen))
        self.assertEqual(server.seen[1].get("session"), "S1")
        self.assertIn("session=S1", refs[0].url)

        with tempfile.TemporaryDirectory() as d:
            paths, credits = tiles.download_tiles(client, refs, LAT, LON, d)
            with open(paths[0], "rb") as f:
                doc, _ = tiles.read_glb(f.read())
        self.assertEqual(credits, Counter({"Data A": 1, "Data B": 1}))
        # node origin was at the target in ECEF -> now at the glTF origin
        matrix = doc["nodes"][0]["matrix"]
        for v in matrix[12:15]:
            self.assertAlmostEqual(v, 0.0, places=4)
        self.assertNotIn("translation", doc["nodes"][0])

    def test_reused_client_root_has_no_session(self):
        server = FakeServer(fake_tileset())
        client = tiles.Client("K", opener=server)
        tiles.select_tiles(client, LAT, LON, radius=150.0, max_error=4.0)
        n = len(server.seen)
        tiles.select_tiles(client, LAT, LON, radius=150.0, max_error=4.0)
        self.assertNotIn("session", server.seen[n])
        self.assertEqual(server.seen[n + 1].get("session"), "S1")

    def test_coarse_stop(self):
        client = tiles.Client("K", opener=FakeServer(fake_tileset()))
        refs = tiles.select_tiles(client, LAT, LON, radius=150.0, max_error=200.0)
        self.assertEqual([urllib.parse.urlparse(r.url).path.rsplit("/", 1)[1] for r in refs], ["coarse.glb"])

    def test_max_tiles(self):
        client = tiles.Client("K", opener=FakeServer(fake_tileset()))
        with self.assertRaises(tiles.TilesError):
            tiles.select_tiles(client, LAT, LON, radius=1e6, max_error=0.1, max_tiles=0)


class RelocateTest(unittest.TestCase):
    def test_rotation_preserved(self):
        # Point 10 m east of the target, expressed via a node TRS in Y-up glTF.
        m = tiles.ecef_to_enu_matrix(LAT, LON)
        east = m[0][:3]
        ecef = [a + 10.0 * e for a, e in zip(tiles.lla_to_ecef(LAT, LON), east)]
        glb = make_glb([ecef[0], ecef[2], -ecef[1]], "")
        out, _ = tiles.relocate_glb(glb, m)
        doc, _ = tiles.read_glb(out)
        t = doc["nodes"][0]["matrix"][12:15]
        # ENU (10, 0, 0) in Y-up glTF is (10, 0, -0)
        self.assertAlmostEqual(t[0], 10.0, places=4)
        self.assertAlmostEqual(t[1], 0.0, places=4)
        self.assertAlmostEqual(t[2], 0.0, places=4)


class MiscTest(unittest.TestCase):
    def test_attribution_order(self):
        self.assertEqual(tiles.attribution(Counter({"B": 1, "A": 3})), "A; B")

    def test_resolve_key(self):
        os.environ.pop(tiles.KEY_ENV, None)
        with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as f:
            f.write("FILEKEY\n")
        try:
            self.assertEqual(tiles.resolve_key("", f.name), "FILEKEY")
            self.assertEqual(tiles.resolve_key("PREF", f.name), "PREF")
            os.environ[tiles.KEY_ENV] = "ENVKEY"
            self.assertEqual(tiles.resolve_key("PREF", f.name), "ENVKEY")
        finally:
            os.environ.pop(tiles.KEY_ENV, None)
            os.unlink(f.name)
        with self.assertRaises(tiles.TilesError):
            tiles.resolve_key("", "/nonexistent")

    def test_resolve_key_json(self):
        os.environ.pop(tiles.KEY_ENV, None)
        with tempfile.TemporaryDirectory() as d:
            good = os.path.join(d, "maps.json")
            with open(good, "w") as f:
                json.dump({"key": "JSONKEY"}, f)
            self.assertEqual(tiles.resolve_key("", good), "JSONKEY")
            bad = os.path.join(d, "bad.json")
            with open(bad, "w") as f:
                json.dump({"other": 1}, f)
            with self.assertRaises(tiles.TilesError):
                tiles.resolve_key("", bad)

    def test_redact(self):
        self.assertNotIn("SECRET", tiles._redact("https://x/y?key=SECRET&session=s"))


if __name__ == "__main__":
    unittest.main()
