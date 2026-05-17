import json
import sys
import os
import pytest
from unittest.mock import MagicMock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))


def make_app(mock_manager=None):
    from tasks_ui import create_app
    return create_app(subdomain='', manager=mock_manager or MagicMock())


def test_index_returns_200():
    app = make_app()
    with app.test_client() as client:
        resp = client.get('/')
        assert resp.status_code == 200


def test_submit_missing_name_returns_400():
    app = make_app()
    with app.test_client() as client:
        resp = client.post('/submit',
                           data=json.dumps({'date': '2026-05-17'}),
                           content_type='application/json')
        assert resp.status_code == 400
        assert 'error' in resp.get_json()


def test_submit_empty_name_returns_400():
    app = make_app()
    with app.test_client() as client:
        resp = client.post('/submit',
                           data=json.dumps({'name': '  ', 'date': '2026-05-17'}),
                           content_type='application/json')
        assert resp.status_code == 400


def test_submit_invalid_json_returns_400():
    app = make_app()
    with app.test_client() as client:
        resp = client.post('/submit',
                           data='not json',
                           content_type='application/json')
        assert resp.status_code == 400


def test_submit_streams_ok_event():
    mock_mgr = MagicMock()
    mock_mgr.putTask.return_value = None
    app = make_app(mock_manager=mock_mgr)
    with app.test_client() as client:
        resp = client.post('/submit',
                           data=json.dumps({'name': 'Test Task', 'date': '2026-05-17'}),
                           content_type='application/json')
        assert resp.status_code == 200
        assert resp.mimetype == 'text/event-stream'
        body = resp.get_data(as_text=True)
        payloads = [json.loads(line[6:]) for line in body.splitlines()
                    if line.startswith('data: ') and '"done"' not in line]
        assert len(payloads) == 1
        assert payloads[0] == {'date': '2026-05-17', 'status': 'ok'}


def test_submit_streams_error_on_api_failure():
    mock_mgr = MagicMock()
    mock_mgr.putTask.side_effect = Exception('API quota exceeded')
    app = make_app(mock_manager=mock_mgr)
    with app.test_client() as client:
        resp = client.post('/submit',
                           data=json.dumps({'name': 'Test', 'date': '2026-05-17'}),
                           content_type='application/json')
        body = resp.get_data(as_text=True)
        payloads = [json.loads(line[6:]) for line in body.splitlines()
                    if line.startswith('data: ') and '"done"' not in line]
        assert payloads[0]['status'] == 'error'
        assert 'API quota exceeded' in payloads[0]['message']


def test_submit_multi_date_range():
    mock_mgr = MagicMock()
    app = make_app(mock_manager=mock_mgr)
    with app.test_client() as client:
        resp = client.post('/submit',
                           data=json.dumps({'name': 'Multi', 'date': '2026-05-17', 'until': '2026-05-19'}),
                           content_type='application/json')
        body = resp.get_data(as_text=True)
        payloads = [json.loads(line[6:]) for line in body.splitlines()
                    if line.startswith('data: ') and '"done"' not in line]
        assert len(payloads) == 3
        assert payloads[0]['date'] == '2026-05-17'
        assert payloads[1]['date'] == '2026-05-18'
        assert payloads[2]['date'] == '2026-05-19'
