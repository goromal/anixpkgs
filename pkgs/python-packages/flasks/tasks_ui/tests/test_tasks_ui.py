import json
import sys
import os
import pytest
from unittest.mock import MagicMock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))


def make_app(mock_manager=None, spec_csv=None):
    from tasks_ui import create_app
    return create_app(subdomain='', manager=mock_manager or MagicMock(), spec_csv=spec_csv)


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


# --- /spec-submit tests ---
# Note: 2026-07-05 is a Sunday (verified: Jan 1, 2026 is Thursday; (3+185)%7=6=Sunday)
# 2026-07-06 is Monday. 2026-07-12 is the next Sunday.
# 2026-07-05 is also the first Sunday of Q3 2026 and first Sunday of July 2026.

def test_spec_submit_missing_start_date_returns_400():
    app = make_app()
    with app.test_client() as client:
        resp = client.post('/spec-submit',
                           data=json.dumps({'end_date': '2026-10-05'}),
                           content_type='application/json')
        assert resp.status_code == 400
        assert 'error' in resp.get_json()


def test_spec_submit_missing_end_date_returns_400():
    app = make_app()
    with app.test_client() as client:
        resp = client.post('/spec-submit',
                           data=json.dumps({'start_date': '2026-07-06'}),
                           content_type='application/json')
        assert resp.status_code == 400


def test_spec_submit_invalid_date_returns_400():
    app = make_app()
    with app.test_client() as client:
        resp = client.post('/spec-submit',
                           data=json.dumps({'start_date': 'not-a-date', 'end_date': '2026-10-05'}),
                           content_type='application/json')
        assert resp.status_code == 400


def test_spec_submit_non_json_returns_400():
    app = make_app()
    with app.test_client() as client:
        resp = client.post('/spec-submit',
                           data='not json',
                           content_type='application/json')
        assert resp.status_code == 400


def test_spec_submit_returns_event_stream(tmp_path):
    csv = tmp_path / 'tasks.csv'
    csv.write_text('w|P0: Weekly Task|\n')
    mock_mgr = MagicMock()
    mock_mgr.getTasks.return_value = []
    mock_mgr.putTask.return_value = None
    app = make_app(mock_manager=mock_mgr, spec_csv=str(csv))
    with app.test_client() as client:
        resp = client.post('/spec-submit',
                           data=json.dumps({'start_date': '2026-07-05', 'end_date': '2026-07-06'}),
                           content_type='application/json')
        assert resp.status_code == 200
        assert resp.mimetype == 'text/event-stream'


def test_spec_submit_sunday_emits_ok_with_weekly_task(tmp_path):
    csv = tmp_path / 'tasks.csv'
    csv.write_text('w|P0: Weekly Task|\n')
    mock_mgr = MagicMock()
    mock_mgr.getTasks.return_value = []
    mock_mgr.putTask.return_value = None
    app = make_app(mock_manager=mock_mgr, spec_csv=str(csv))
    with app.test_client() as client:
        resp = client.post('/spec-submit',
                           data=json.dumps({'start_date': '2026-07-05', 'end_date': '2026-07-05'}),
                           content_type='application/json')
        body = resp.get_data(as_text=True)
        payloads = [json.loads(line[6:]) for line in body.splitlines()
                    if line.startswith('data: ') and '"done"' not in line]
        assert len(payloads) == 1
        assert payloads[0]['status'] == 'ok'
        assert 'P0: Weekly Task' in payloads[0]['tasks']


def test_spec_submit_non_sunday_emits_skip(tmp_path):
    csv = tmp_path / 'tasks.csv'
    csv.write_text('w|P0: Weekly Task|\n')
    mock_mgr = MagicMock()
    mock_mgr.getTasks.return_value = []
    app = make_app(mock_manager=mock_mgr, spec_csv=str(csv))
    with app.test_client() as client:
        resp = client.post('/spec-submit',
                           data=json.dumps({'start_date': '2026-07-06', 'end_date': '2026-07-06'}),
                           content_type='application/json')
        body = resp.get_data(as_text=True)
        payloads = [json.loads(line[6:]) for line in body.splitlines()
                    if line.startswith('data: ') and '"done"' not in line]
        assert len(payloads) == 1
        assert payloads[0]['status'] == 'skip'


def test_spec_submit_get_tasks_error_emits_error(tmp_path):
    csv = tmp_path / 'tasks.csv'
    csv.write_text('w|P0: Weekly Task|\n')
    mock_mgr = MagicMock()
    mock_mgr.getTasks.side_effect = Exception('API error')
    app = make_app(mock_manager=mock_mgr, spec_csv=str(csv))
    with app.test_client() as client:
        resp = client.post('/spec-submit',
                           data=json.dumps({'start_date': '2026-07-05', 'end_date': '2026-07-05'}),
                           content_type='application/json')
        body = resp.get_data(as_text=True)
        payloads = [json.loads(line[6:]) for line in body.splitlines()
                    if line.startswith('data: ') and '"done"' not in line]
        assert payloads[0]['status'] == 'error'
        assert 'API error' in payloads[0]['message']


def test_spec_submit_put_task_error_continues_stream(tmp_path):
    csv = tmp_path / 'tasks.csv'
    csv.write_text('w|P0: Weekly Task|\n')
    mock_mgr = MagicMock()
    mock_mgr.getTasks.return_value = []
    # First Sunday (2026-07-05) fails, second Sunday (2026-07-12) succeeds
    mock_mgr.putTask.side_effect = [Exception('quota'), None]
    app = make_app(mock_manager=mock_mgr, spec_csv=str(csv))
    with app.test_client() as client:
        resp = client.post('/spec-submit',
                           data=json.dumps({'start_date': '2026-07-05', 'end_date': '2026-07-12'}),
                           content_type='application/json')
        body = resp.get_data(as_text=True)
        payloads = [json.loads(line[6:]) for line in body.splitlines()
                    if line.startswith('data: ') and '"done"' not in line]
        non_skip = [p for p in payloads if p['status'] != 'skip']
        assert len(non_skip) == 2
        assert non_skip[0]['status'] == 'error'
        assert non_skip[1]['status'] == 'ok'


# --- /spec-csv tests ---

def test_spec_csv_get_returns_items(tmp_path):
    csv = tmp_path / 'tasks.csv'
    csv.write_text('w|P0: Weekly Task|some notes\n')
    app = make_app(spec_csv=str(csv))
    with app.test_client() as client:
        resp = client.get('/spec-csv')
        assert resp.status_code == 200
        data = resp.get_json()
        assert 'items' in data
        assert len(data['items']) == 1
        assert data['items'][0] == {'interval': 'w', 'title': 'P0: Weekly Task', 'desc': 'some notes'}


def test_spec_csv_get_missing_file_returns_empty(tmp_path):
    nonexistent = str(tmp_path / 'no-such-file.csv')
    app = make_app(spec_csv=nonexistent)
    with app.test_client() as client:
        resp = client.get('/spec-csv')
        assert resp.status_code == 200
        assert resp.get_json() == {'items': []}


def test_spec_csv_post_writes_file(tmp_path):
    csv_path = str(tmp_path / 'tasks.csv')
    app = make_app(spec_csv=csv_path)
    items = [
        {'interval': 'd', 'title': 'Daily standup', 'desc': ''},
        {'interval': 'w', 'title': 'Weekly review', 'desc': 'check metrics'},
    ]
    with app.test_client() as client:
        resp = client.post('/spec-csv',
                           data=json.dumps({'items': items}),
                           content_type='application/json')
        assert resp.status_code == 200
        assert resp.get_json() == {'ok': True}
    content = open(csv_path).read()
    assert 'd|Daily standup|\n' in content
    assert 'w|Weekly review|check metrics\n' in content


def test_spec_csv_post_non_json_returns_400():
    app = make_app()
    with app.test_client() as client:
        resp = client.post('/spec-csv',
                           data='not json',
                           content_type='application/json')
        assert resp.status_code == 400
        assert 'error' in resp.get_json()


def test_spec_csv_post_missing_items_returns_400():
    app = make_app()
    with app.test_client() as client:
        resp = client.post('/spec-csv',
                           data=json.dumps({}),
                           content_type='application/json')
        assert resp.status_code == 400
        assert 'error' in resp.get_json()


def test_spec_submit_idempotent_skips_existing(tmp_path):
    csv = tmp_path / 'tasks.csv'
    csv.write_text('w|P0: Weekly Task|\n')
    mock_mgr = MagicMock()
    existing = MagicMock()
    existing.name = 'P0: Weekly Task'
    mock_mgr.getTasks.return_value = [existing]
    app = make_app(mock_manager=mock_mgr, spec_csv=str(csv))
    with app.test_client() as client:
        resp = client.post('/spec-submit',
                           data=json.dumps({'start_date': '2026-07-05', 'end_date': '2026-07-05'}),
                           content_type='application/json')
        body = resp.get_data(as_text=True)
        payloads = [json.loads(line[6:]) for line in body.splitlines()
                    if line.startswith('data: ') and '"done"' not in line]
        assert payloads[0]['status'] == 'ok'
        assert payloads[0]['tasks'] == []
        mock_mgr.putTask.assert_not_called()


def test_spec_csv_get_returns_interval_with_day_suffix(tmp_path):
    csv = tmp_path / 'tasks.csv'
    csv.write_text('w:mon|Monday Task|notes\n')
    app = make_app(spec_csv=str(csv))
    with app.test_client() as client:
        resp = client.get('/spec-csv')
        assert resp.status_code == 200
        data = resp.get_json()
        assert data['items'][0] == {'interval': 'w:mon', 'title': 'Monday Task', 'desc': 'notes'}


def test_spec_submit_w_mon_spawns_on_monday(tmp_path):
    csv = tmp_path / 'tasks.csv'
    csv.write_text('w:mon|Monday Task|\n')
    mock_mgr = MagicMock()
    mock_mgr.getTasks.return_value = []
    app = make_app(mock_manager=mock_mgr, spec_csv=str(csv))
    with app.test_client() as client:
        # 2026-06-01 is Monday; range Mon–Sun contains exactly one Monday
        resp = client.post('/spec-submit',
                           data=json.dumps({'start_date': '2026-06-01', 'end_date': '2026-06-07'}),
                           content_type='application/json')
        body = resp.get_data(as_text=True)
        payloads = [json.loads(line[6:]) for line in body.splitlines()
                    if line.startswith('data: ') and '"done"' not in line]
        ok_payloads = [p for p in payloads if p['status'] == 'ok']
        assert len(ok_payloads) == 1
        assert ok_payloads[0]['date'] == '2026-06-01'
        mock_mgr.putTask.assert_called_once()


def test_spec_submit_w_mon_does_not_spawn_on_sunday(tmp_path):
    csv = tmp_path / 'tasks.csv'
    csv.write_text('w:mon|Monday Task|\n')
    mock_mgr = MagicMock()
    mock_mgr.getTasks.return_value = []
    app = make_app(mock_manager=mock_mgr, spec_csv=str(csv))
    with app.test_client() as client:
        # 2026-07-05 is Sunday; no Monday in this 1-day range
        resp = client.post('/spec-submit',
                           data=json.dumps({'start_date': '2026-07-05', 'end_date': '2026-07-05'}),
                           content_type='application/json')
        body = resp.get_data(as_text=True)
        payloads = [json.loads(line[6:]) for line in body.splitlines()
                    if line.startswith('data: ') and '"done"' not in line]
        non_skip = [p for p in payloads if p['status'] != 'skip']
        assert len(non_skip) == 0


def test_spec_submit_invalid_day_token_returns_400(tmp_path):
    csv = tmp_path / 'tasks.csv'
    csv.write_text('w:xyz|Bad Task|\n')
    app = make_app(spec_csv=str(csv))
    with app.test_client() as client:
        resp = client.post('/spec-submit',
                           data=json.dumps({'start_date': '2026-06-01', 'end_date': '2026-06-07'}),
                           content_type='application/json')
        assert resp.status_code == 400
        assert 'error' in resp.get_json()
