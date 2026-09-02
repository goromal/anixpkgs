import json
import os

import pytest

from grafana_dash.cli import PROM_UID, LOKI_UID, sanitize_dashboard, sanitize_files

FIXTURE = os.path.join(os.path.dirname(__file__), "node-exporter-full.json")


def _write_dashboard(path, uid):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps({"uid": uid, "title": uid, "panels": []}))
    return str(path)


def test_sanitize_strips_import_only_keys():
    out = sanitize_dashboard(
        {"__inputs": [{"name": "DS_PROMETHEUS"}], "__elements": {}, "__requires": [],
         "uid": "abc", "title": "T", "panels": []}
    )
    assert "__inputs" not in out
    assert "__elements" not in out
    assert "__requires" not in out


def test_sanitize_rewrites_datasource_uids_by_type():
    out = sanitize_dashboard(
        {
            "uid": "abc",
            "title": "T",
            "panels": [
                {"datasource": {"type": "prometheus", "uid": "${DS_PROMETHEUS}"},
                 "targets": [{"datasource": {"type": "prometheus", "uid": "aeeiaf95w6arkc"}}]},
                {"datasource": {"type": "loki", "uid": "P8E80F9AEF21F6940"}},
            ],
        }
    )
    assert out["panels"][0]["datasource"]["uid"] == PROM_UID
    assert out["panels"][0]["targets"][0]["datasource"]["uid"] == PROM_UID
    assert out["panels"][1]["datasource"]["uid"] == LOKI_UID


def test_sanitize_preserves_builtin_grafana_datasources():
    out = sanitize_dashboard(
        {"uid": "abc", "title": "T",
         "panels": [{"datasource": {"type": "grafana", "uid": "-- Grafana --"}}]}
    )
    assert out["panels"][0]["datasource"]["uid"] == "-- Grafana --"


def test_sanitize_drops_datasource_template_variables():
    out = sanitize_dashboard(
        {"uid": "abc", "title": "T", "panels": [],
         "templating": {"list": [
             {"name": "DS_PROMETHEUS", "type": "datasource"},
             {"name": "job", "type": "query"},
         ]}}
    )
    names = [v["name"] for v in out["templating"]["list"]]
    assert names == ["job"]


def test_sanitize_resets_id_and_version_but_keeps_identity():
    out = sanitize_dashboard({"uid": "abc", "title": "T", "id": 7, "version": 9, "panels": []})
    assert out["id"] is None
    assert out["version"] == 1
    assert out["uid"] == "abc"
    assert out["title"] == "T"


def test_sanitize_does_not_mutate_its_input():
    dashboard = {
        "uid": "abc", "title": "T", "id": 7, "version": 9,
        "__inputs": [{"name": "DS_PROMETHEUS"}],
        "panels": [{"datasource": {"type": "prometheus", "uid": "${DS_PROMETHEUS}"}}],
        "templating": {"list": [{"name": "DS_PROMETHEUS", "type": "datasource"}]},
    }
    before = json.dumps(dashboard, sort_keys=True)
    sanitize_dashboard(dashboard)
    assert json.dumps(dashboard, sort_keys=True) == before


def test_sanitize_real_node_exporter_full_leaves_no_unresolved_inputs():
    with open(FIXTURE) as f:
        raw = json.load(f)
    out = sanitize_dashboard(raw)
    assert "${DS_" not in json.dumps(out)
    assert len(out["panels"]) == 32


def test_sanitize_preserves_builtin_datasource_in_real_fixture():
    # The vendored export uses the {"type": "datasource", "uid": "grafana"} form
    # of the built-in datasource, not the "-- Grafana --" form.
    with open(FIXTURE) as f:
        raw = json.load(f)
    out = sanitize_dashboard(raw)
    annotation = out["annotations"]["list"][0]
    assert annotation["datasource"] == {"type": "datasource", "uid": "grafana"}


def test_sanitize_files_writes_one_output_per_input(tmp_path):
    inputs = [
        _write_dashboard(tmp_path / "src" / "a.json", "uid-a"),
        _write_dashboard(tmp_path / "src" / "b.json", "uid-b"),
    ]
    out_dir = tmp_path / "out"

    sanitize_files(inputs, str(out_dir))

    assert sorted(p.name for p in out_dir.iterdir()) == ["a.json", "b.json"]
    assert json.loads((out_dir / "a.json").read_text())["uid"] == "uid-a"
    assert json.loads((out_dir / "b.json").read_text())["uid"] == "uid-b"


def test_sanitize_files_rejects_duplicate_basenames_without_writing(tmp_path):
    inputs = [
        _write_dashboard(tmp_path / "one" / "dash.json", "uid-a"),
        _write_dashboard(tmp_path / "two" / "dash.json", "uid-b"),
    ]
    out_dir = tmp_path / "out"

    with pytest.raises(ValueError, match="dash.json"):
        sanitize_files(inputs, str(out_dir))

    assert not out_dir.exists()
