import json

import pytest

import cozy


def test_load_secrets_missing_file(tmp_path):
    with pytest.raises(SystemExit):
        cozy._load_secrets(str(tmp_path / "nope.json"))


def test_load_secrets_invalid_json(tmp_path):
    p = tmp_path / "s.json"
    p.write_text("{not json")
    with pytest.raises(SystemExit):
        cozy._load_secrets(str(p))


def test_load_secrets_missing_field(tmp_path):
    p = tmp_path / "s.json"
    p.write_text(json.dumps({"secret_key": "abc"}))
    with pytest.raises(SystemExit):
        cozy._load_secrets(str(p))


def test_load_secrets_ok(tmp_path):
    p = tmp_path / "s.json"
    p.write_text(json.dumps({"secret_key": "abc", "password_hash": "scrypt:x"}))
    data = cozy._load_secrets(str(p))
    assert data["secret_key"] == "abc"
    assert data["password_hash"] == "scrypt:x"
