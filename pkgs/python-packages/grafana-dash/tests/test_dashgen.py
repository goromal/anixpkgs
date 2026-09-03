import json
import os
import sys

import pytest

from grafana_dash.cli import (
    PROM_UID,
    LOKI_UID,
    lint_dashboards,
    lint_files,
    main,
    render_dashboard,
    render_files,
    sanitize_dashboard,
    sanitize_files,
)

FIXTURE = os.path.join(os.path.dirname(__file__), "node-exporter-full.json")


def _write_dashboard(path, uid):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps({"uid": uid, "title": uid, "panels": []}))
    return str(path)


# --- sanitize ---------------------------------------------------------------


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


def test_sanitize_files_names_the_file_that_does_not_parse(tmp_path):
    # Which of N inputs is malformed is the whole question inside a build log.
    inputs = [
        _write_dashboard(tmp_path / "src" / "good.json", "uid-a"),
        str(tmp_path / "src" / "broken.json"),
    ]
    (tmp_path / "src" / "broken.json").write_text("{oops")

    with pytest.raises(ValueError, match="broken.json"):
        sanitize_files(inputs, str(tmp_path / "out"))


# --- render -----------------------------------------------------------------


SPEC = {
    "hostname": "testhost",
    "panels": [
        {"kind": "timeseries", "title": "Completed", "metric": "orchestrator_jobs_completed",
         "group": "Orchestrator", "unit": "short", "width": 12, "dashboard": "diagnostics"},
        {"kind": "timeseries", "title": "Discarded", "metric": "orchestrator_jobs_discarded",
         "group": "Orchestrator", "unit": "short", "width": 12, "dashboard": "diagnostics"},
        {"kind": "logs", "title": "Mailman", "tag": "ats-mailman",
         "group": "Logs", "unit": "short", "width": 24, "dashboard": "diagnostics"},
    ],
}


def test_render_groups_panels_into_rows():
    out = render_dashboard("diagnostics", SPEC["panels"], SPEC["hostname"])
    rows = [p for p in out["panels"] if p["type"] == "row"]
    assert [r["title"] for r in rows] == ["Orchestrator", "Logs"]

    # A panel naming neither a group nor a dashboard falls back to both defaults.
    loose = render_dashboard(
        "diagnostics",
        SPEC["panels"] + [{"kind": "stat", "title": "Loose", "metric": "m"}],
        SPEC["hostname"],
    )
    assert [p["title"] for p in loose["panels"] if p["type"] == "row"] == [
        "Orchestrator",
        "Logs",
        "General",
    ]


def test_render_packs_grid_positions_into_24_columns():
    out = render_dashboard("diagnostics", SPEC["panels"], SPEC["hostname"])
    body = [p for p in out["panels"] if p["type"] != "row"]
    assert body[0]["gridPos"]["x"] == 0
    assert body[1]["gridPos"]["x"] == 12
    assert body[2]["gridPos"]["x"] == 0
    assert body[2]["gridPos"]["y"] > body[1]["gridPos"]["y"]
    # A new group starts below the previous group's panels, not on top of them.
    assert body[2]["gridPos"]["y"] >= body[1]["gridPos"]["y"] + body[1]["gridPos"]["h"]

    # Every panel sits below its row header rather than on top of it.
    header_y = None
    for panel in out["panels"]:
        if panel["type"] == "row":
            header_y = panel["gridPos"]["y"]
        else:
            assert header_y is not None
            assert panel["gridPos"]["y"] > header_y


def test_render_wraps_and_clamps_oversized_panels():
    # Three half-width panels do not fit on one 24-column row, so the third wraps.
    # The fourth is wider than the grid and is clamped to full width.
    widths = [
        {"kind": "stat", "title": title, "metric": "m", "group": "G", "width": width}
        for title, width in (("A", 12), ("B", 12), ("C", 12), ("D", 30))
    ]
    rendered = render_dashboard("diagnostics", widths, "h")
    wrapped = [p for p in rendered["panels"] if p["type"] != "row"]
    assert [p["gridPos"]["x"] for p in wrapped] == [0, 12, 0, 0]
    assert [p["gridPos"]["w"] for p in wrapped] == [12, 12, 12, 24]
    assert wrapped[2]["gridPos"]["y"] > wrapped[1]["gridPos"]["y"]

    # An unspecified width defaults to half the grid.
    bare = render_dashboard(
        "diagnostics", [{"kind": "stat", "title": "E", "metric": "m"}], "h"
    )
    assert [p["gridPos"]["w"] for p in bare["panels"] if p["type"] != "row"] == [12]


def test_render_assigns_unique_panel_ids():
    # Grafana keys panels by id, so ids must be unique across the dashboard.
    out = render_dashboard("diagnostics", SPEC["panels"], SPEC["hostname"])
    ids = [p["id"] for p in out["panels"]]
    assert len(ids) == len(set(ids))


def test_render_assigns_pinned_datasource_uids():
    out = render_dashboard("diagnostics", SPEC["panels"], SPEC["hostname"])
    body = [p for p in out["panels"] if p["type"] != "row"]
    assert body[0]["datasource"]["uid"] == PROM_UID
    assert body[2]["datasource"]["uid"] == LOKI_UID


def test_render_builds_queries_from_metric_and_tag():
    out = render_dashboard("diagnostics", SPEC["panels"], SPEC["hostname"])
    body = [p for p in out["panels"] if p["type"] != "row"]
    assert body[0]["targets"][0]["expr"] == "orchestrator_jobs_completed"
    assert body[2]["targets"][0]["expr"] == '{tag="ats-mailman"}'

    # Neither `expr` nor `metric` is a spec bug. Raise rather than render a
    # valid-looking dashboard whose panel is silently blank -- the same policy
    # the logs branch gets for free from a missing `tag`.
    with pytest.raises(KeyError):
        render_dashboard(
            "diagnostics", [{"kind": "timeseries", "title": "Broken"}], "h"
        )
    with pytest.raises(KeyError):
        render_dashboard("diagnostics", [{"kind": "logs", "title": "Broken"}], "h")


def test_render_propagates_unit_with_short_default():
    # `unit` propagates from the spec the same way a query does, defaulting to
    # "short". It is what makes a byte count render as bytes, not a bare number.
    units = render_dashboard(
        "diagnostics",
        [
            {"kind": "stat", "title": "Disk", "metric": "d", "group": "G", "unit": "bytes"},
            {"kind": "stat", "title": "Count", "metric": "c", "group": "G"},
        ],
        "h",
    )
    assert [
        p["fieldConfig"]["defaults"]["unit"]
        for p in units["panels"]
        if p["type"] != "row"
    ] == ["bytes", "short"]


def test_render_expr_overrides_metric():
    panels = [{"kind": "timeseries", "title": "Rate", "metric": "ignored",
               "expr": "rate(x[5m])", "group": "G", "unit": "short",
               "width": 12, "dashboard": "diagnostics"}]
    out = render_dashboard("diagnostics", panels, "h")
    body = [p for p in out["panels"] if p["type"] != "row"]
    assert body[0]["targets"][0]["expr"] == "rate(x[5m])"


def test_render_uid_is_stable_across_calls():
    a = render_dashboard("diagnostics", SPEC["panels"], "hostA")
    b = render_dashboard("diagnostics", SPEC["panels"], "hostB")
    assert a["uid"] == b["uid"]
    assert a["uid"].startswith("anix-")


def test_render_files_writes_a_reproducible_file_per_dashboard(tmp_path):
    spec = {
        "hostname": "testhost",
        "panels": SPEC["panels"] + [
            {"kind": "stat", "title": "Uptime", "metric": "up", "group": "Host",
             "width": 6, "dashboard": "overview"},
        ],
    }

    render_files(spec, str(tmp_path / "a"))
    render_files(spec, str(tmp_path / "b"))

    assert sorted(p.name for p in (tmp_path / "a").iterdir()) == [
        "diagnostics.json",
        "overview.json",
    ]

    # Each dashboard gets only the panels that named it.
    diagnostics = json.loads((tmp_path / "a" / "diagnostics.json").read_text())
    assert diagnostics["uid"] == "anix-diagnostics"
    assert [p["title"] for p in diagnostics["panels"] if p["type"] != "row"] == [
        "Completed",
        "Discarded",
        "Mailman",
    ]

    # Task 4 hashes these files into a store path, so the bytes must not churn.
    # Identical output across runs is necessary but not sufficient: dict order is
    # already deterministic, so key order is only pinned if sort_keys is in play.
    text = (tmp_path / "a" / "diagnostics.json").read_text()
    assert text == (tmp_path / "b" / "diagnostics.json").read_text()
    top_level_keys = json.loads(text, object_pairs_hook=lambda kvs: [k for k, _ in kvs])
    assert top_level_keys == sorted(top_level_keys)


def test_render_files_rejects_dashboard_names_that_escape_the_output_dir(tmp_path):
    # Only this check can see an escaping name; see _VALID_STEM in dashgen.py.
    out_dir = tmp_path / "out"
    for name in ("../evil", "sub/evil"):
        # The good dashboard trailing the bad one matters: every name is checked,
        # not just whichever one the name-collecting loop happened to end on.
        spec = {"hostname": "h", "panels": [
            {"kind": "stat", "title": "Evil", "metric": "m", "dashboard": name},
            {"kind": "stat", "title": "Fine", "metric": "m", "dashboard": "ok"}]}
        with pytest.raises(ValueError, match="evil") as caught:
            render_files(spec, str(out_dir))
        # The message is where a reader learns what a legal name looks like.
        assert "allowed: A-Z a-z 0-9 _ -" in str(caught.value)

    # Nothing anywhere: not in the output directory, and not beside it either.
    assert not out_dir.exists()
    assert list(tmp_path.iterdir()) == []


def test_render_cli_names_a_spec_that_does_not_parse(tmp_path, capsys, monkeypatch):
    # The third _load_json call site: the spec comes from Nix, so a parse failure
    # here means a generator bug, and the log has to say which file.
    spec = tmp_path / "spec.json"
    spec.write_text("{oops")
    monkeypatch.setattr(sys, "argv", ["grafana_dash", "render", "--spec", str(spec),
                                      "--out", str(tmp_path / "out")])

    assert main() == 1

    err = capsys.readouterr().err.splitlines()
    assert len(err) == 1
    assert err[0].startswith("grafana_dash: error: ")
    assert "spec.json" in err[0]


# --- lint -------------------------------------------------------------------


def test_lint_accepts_rendered_and_sanitized_output():
    # Both halves of what the derivation provisions must lint clean. The rendered
    # half also pins the row-panel tolerance: `render` emits one row per group and
    # rows legitimately carry no `datasource`.
    with open(FIXTURE) as f:
        vendored = sanitize_dashboard(json.load(f))
    rendered = render_dashboard("diagnostics", SPEC["panels"], SPEC["hostname"])
    assert any(p["type"] == "row" for p in rendered["panels"])
    assert lint_dashboards({"node.json": vendored, "diagnostics.json": rendered}) == []


def test_lint_finds_datasources_at_every_nesting_depth():
    # A dashboard's datasources are not all at panel top level: `render` puts one
    # on every target, a collapsed row hides its panels a level down, and template
    # variables carry their own. A walk that stops at panels sees none of these.
    deep = {
        "uid": "a", "title": "A",
        "panels": [
            {"type": "timeseries", "title": "T",
             "datasource": {"type": "prometheus", "uid": PROM_UID},
             "targets": [{"datasource": {"type": "prometheus", "uid": "in-target"}}]},
            {"type": "row", "title": "R", "collapsed": True,
             "panels": [{"datasource": {"type": "prometheus", "uid": "in-row"}}]},
        ],
        "templating": {"list": [
            {"name": "job", "type": "query",
             "datasource": {"type": "prometheus", "uid": "in-variable"}},
        ]},
    }
    assert lint_dashboards({"deep.json": deep}) == [
        "deep.json: unknown datasource uid 'in-row'",
        "deep.json: unknown datasource uid 'in-target'",
        "deep.json: unknown datasource uid 'in-variable'",
    ]


def test_lint_rejects_unknown_datasource_uid():
    # One finding per distinct uid per dashboard: repeats within a dashboard
    # collapse so the build log stays readable, each file keeps its own finding,
    # and the order is sorted rather than whatever the JSON happened to say.
    panel = {"datasource": {"type": "prometheus", "uid": "zz-dedb5gw15rls0c"}}
    other = {"datasource": {"type": "prometheus", "uid": "aa-p8e80f9aef21f69"}}
    errors = lint_dashboards({
        "a.json": {"uid": "a", "title": "A", "panels": [panel, panel, other]},
        "b.json": {"uid": "b", "title": "B", "panels": [panel]},
    })
    assert errors == [
        "a.json: unknown datasource uid 'aa-p8e80f9aef21f69'",
        "a.json: unknown datasource uid 'zz-dedb5gw15rls0c'",
        "b.json: unknown datasource uid 'zz-dedb5gw15rls0c'",
    ]


def test_lint_rejects_unresolved_input_token():
    bad = {"uid": "a", "title": "A",
           "panels": [{"datasource": {"type": "prometheus", "uid": "${DS_PROMETHEUS}"}}]}
    errors = lint_dashboards({"bad.json": bad})
    # Reported as unresolved rather than merely unknown: a `${` uid means the
    # export was never sanitized, which is a different fix from a stale uid.
    assert any("unresolved" in e and "${DS_PROMETHEUS}" in e for e in errors)


def test_lint_rejects_string_form_datasource():
    # sanitize only rewrites the object form, so a pre-Grafana-8 export would
    # otherwise pass straight through to a host.
    bad = {"uid": "a", "title": "A",
           "panels": [{"datasource": "${DS_PROMETHEUS}"},
                      {"datasource": "${DS_PROMETHEUS}"}]}
    errors = lint_dashboards({"bad.json": bad})
    assert len(errors) == 1
    assert "string-form datasource" in errors[0] and "${DS_PROMETHEUS}" in errors[0]


def test_lint_rejects_string_form_datasource_naming_a_known_uid():
    # The shape is the defect, not the value: Grafana 8+ resolves `datasource` by
    # object, so a bare string does not resolve even when it names a real one.
    bad = {"uid": "a", "title": "A", "panels": [{"datasource": "grafana"}]}
    errors = lint_dashboards({"bad.json": bad})
    assert errors == [
        "bad.json: string-form datasource 'grafana' is a pre-Grafana-8 shape "
        "and will not resolve"
    ]


def test_lint_rejects_duplicate_dashboard_uids():
    one = {"uid": "dup", "title": "One", "panels": []}
    two = {"uid": "dup", "title": "Two", "panels": []}
    # Insertion order is deliberately not sorted order: the report names the file
    # that loses the race by filename, so it does not churn with caller order.
    errors = lint_dashboards({"b.json": two, "a.json": one})
    assert errors == ["b.json: duplicate dashboard uid 'dup' (also in a.json)"]


def test_lint_rejects_missing_identity_fields():
    # Each field is checked independently: a dashboard with a uid but no title is
    # just as unusable as one with neither.
    errors = lint_dashboards({
        "a.json": {"uid": "", "title": "A", "panels": []},
        "b.json": {"uid": "b", "title": "", "panels": []},
    })
    assert errors == ["a.json: missing uid", "b.json: missing title"]


def test_lint_rejects_filenames_that_are_not_plain_identifiers():
    # The output-directory end of the check; see _VALID_STEM in dashgen.py.
    errors = lint_dashboards({
        "../evil.json": {"uid": "a", "title": "A", "panels": []},
        "sub/evil.json": {"uid": "b", "title": "B", "panels": []},
    })
    assert len(errors) == 2
    assert all("not a plain identifier (allowed: A-Z a-z 0-9 _ -)" in e for e in errors)


def test_lint_files_reads_only_json_and_keys_findings_by_filename(tmp_path):
    (tmp_path / "good.json").write_text(json.dumps({"uid": "g", "title": "G", "panels": []}))
    (tmp_path / "bad.json").write_text(json.dumps({"uid": "", "title": "B", "panels": []}))
    (tmp_path / "notes.txt").write_text("not a dashboard, and not valid JSON either")

    errors, linted = lint_files(str(tmp_path))

    assert errors == ["bad.json: missing uid"]
    assert linted == 2


def test_lint_files_rejects_an_empty_directory(tmp_path):
    # Zero dashboards is the silently-broken outcome lint exists to convert into a
    # build failure: a provisioning run always renders at least one.
    errors, linted = lint_files(str(tmp_path))

    assert len(errors) == 1
    assert str(tmp_path) in errors[0]
    assert linted == 0


def test_lint_files_names_the_file_that_does_not_parse(tmp_path):
    (tmp_path / "broken.json").write_text("{oops")

    with pytest.raises(ValueError, match="broken.json"):
        lint_files(str(tmp_path))


def test_lint_cli_prints_errors_to_stderr_and_exits_nonzero(tmp_path, capsys, monkeypatch):
    (tmp_path / "bad.json").write_text(json.dumps({"uid": "", "title": "T", "panels": []}))
    monkeypatch.setattr(sys, "argv", ["grafana_dash", "lint", str(tmp_path)])

    assert main() == 1

    # Every line carries the program name, because Nix interleaves builder logs,
    # and the trailing count is what survives a truncated one.
    assert capsys.readouterr().err.splitlines() == [
        "grafana_dash: bad.json: missing uid",
        "grafana_dash: 1 problem(s) in 1 dashboard(s)",
    ]


def test_lint_cli_names_an_unparseable_file_with_the_program_name(tmp_path, capsys,
                                                                 monkeypatch):
    (tmp_path / "broken.json").write_text("{oops")
    monkeypatch.setattr(sys, "argv", ["grafana_dash", "lint", str(tmp_path)])

    assert main() == 1

    # Raised errors reach the log through main()'s handler wearing the same prefix
    # as the findings above -- not as a traceback, and never nameless.
    err = capsys.readouterr().err.splitlines()
    assert len(err) == 1
    assert err[0].startswith("grafana_dash: error: ")
    assert "broken.json" in err[0]


def test_lint_cli_exits_zero_and_says_nothing_on_a_clean_directory(tmp_path, capsys,
                                                                   monkeypatch):
    # Task 4 runs this inside the derivation, so a clean directory has to succeed
    # as reliably as a dirty one has to fail -- and quietly, so the summary line
    # only ever appears when there is something to summarize.
    render_files(SPEC, str(tmp_path))
    monkeypatch.setattr(sys, "argv", ["grafana_dash", "lint", str(tmp_path)])

    assert main() == 0

    assert capsys.readouterr().err == ""
