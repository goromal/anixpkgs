import argparse
import datetime
import json
import os
import subprocess

from flask import Flask, Blueprint, request, render_template, Response, stream_with_context
# parse_interval and _all_weeks_on_day are module-level helpers in task_tools.cli.
# They are imported directly rather than from a shared utils module — update this
# import if those helpers are ever moved.
from task_tools.cli import parse_interval, _all_weeks_on_day


def _init_manager():
    from task_tools.manage import TaskManager
    try:
        return TaskManager(), None
    except Exception as e:
        return None, str(e)


def _first_sundays_of_month(start, end):
    result = []
    month = start.month
    year = start.year
    while datetime.datetime(year, month, 1) <= end:
        first = datetime.datetime(year, month, 1)
        while first.weekday() != 6:
            first += datetime.timedelta(days=1)
        if start <= first <= end:
            result.append(first)
        if month == 12:
            month = 1
            year += 1
        else:
            month += 1
    return result


def _first_sundays_of_quarter(start, end):
    quarter_months = {1, 4, 7, 10}
    return [d for d in _first_sundays_of_month(start, end) if d.month in quarter_months]


def _read_spec_csv(path):
    items = []
    with open(path, 'r') as f:
        for line in f:
            parts = line.split('|', 2)
            if len(parts) < 2:
                continue
            rtype = parts[0].strip()
            title = parts[1].strip()
            desc = parts[2].strip() if len(parts) > 2 else ''
            items.append((rtype, title, desc))
    return items


def create_app(subdomain='', manager=None, spec_csv=None):
    _spec_csv = os.path.expanduser(spec_csv or '~/configs/intervaled-tasks.csv')
    app = Flask(__name__)
    bp = Blueprint('tasks', __name__, url_prefix=subdomain)

    def _get_manager():
        if manager is not None:
            return manager, None
        # Re-initialize each request so credentials are always fresh from disk.
        return _init_manager()

    @bp.route('/', methods=['GET'])
    def index():
        return render_template('main.html', subdomain=subdomain)

    @bp.route('/submit', methods=['POST'])
    def submit():
        mgr, err = _get_manager()
        if mgr is None:
            return {'error': f'TaskManager not initialized — {err}'}, 500

        data = request.get_json(silent=True)
        if data is None:
            return {'error': 'Invalid JSON'}, 400

        name = (data.get('name') or '').strip()
        if not name:
            return {'error': 'name is required'}, 400

        notes = data.get('notes') or ''
        date_str = data.get('date')
        until_str = data.get('until')

        try:
            start = datetime.datetime.strptime(date_str, '%Y-%m-%d')
        except (TypeError, ValueError):
            return {'error': 'invalid date'}, 400

        if until_str:
            try:
                end = datetime.datetime.strptime(until_str, '%Y-%m-%d')
            except ValueError:
                return {'error': 'invalid until'}, 400
            if end < start:
                end = start
        else:
            end = start

        def generate():
            current = start
            while current <= end:
                label = current.strftime('%Y-%m-%d')
                try:
                    mgr.putTask(name, notes, current)
                    event = json.dumps({'date': label, 'status': 'ok'})
                except Exception as exc:
                    event = json.dumps({'date': label, 'status': 'error', 'message': str(exc)})
                yield f'data: {event}\n\n'
                current += datetime.timedelta(days=1)
            yield 'data: {"done": true}\n\n'

        return Response(stream_with_context(generate()), mimetype='text/event-stream')

    @bp.route('/spec-csv', methods=['GET'])
    def spec_csv_get():
        try:
            items = _read_spec_csv(_spec_csv)
        except FileNotFoundError:
            return {'items': []}
        return {'items': [{'interval': rtype, 'title': title, 'desc': desc}
                           for rtype, title, desc in items]}

    @bp.route('/spec-csv', methods=['POST'])
    def spec_csv_post():
        data = request.get_json(silent=True)
        if data is None:
            return {'error': 'Invalid JSON'}, 400
        if 'items' not in data:
            return {'error': 'missing items key'}, 400
        for item in data['items']:
            title = str(item.get('title', '') or '').strip()
            desc = str(item.get('desc', '') or '').strip()
            if '|' in title or '|' in desc:
                return {'error': 'title and desc may not contain | characters'}, 400
        try:
            parent = os.path.dirname(_spec_csv)
            if parent:
                os.makedirs(parent, exist_ok=True)
            with open(_spec_csv, 'w') as f:
                for item in data['items']:
                    interval = item.get('interval', '')
                    title = item.get('title', '')
                    desc = item.get('desc', '')
                    f.write(f'{interval}|{title}|{desc}\n')
        except Exception as e:
            return {'error': str(e)}, 500
        try:
            subprocess.run(['rcrsync', 'override', 'configs'], check=True, capture_output=True)
        except Exception as e:
            return {'ok': True, 'warning': f'File saved but cloud sync failed: {e}'}
        return {'ok': True}

    @bp.route('/spec-submit', methods=['POST'])
    def spec_submit():
        mgr, err = _get_manager()
        if mgr is None:
            return {'error': f'TaskManager not initialized — {err}'}, 500

        data = request.get_json(silent=True)
        if data is None:
            return {'error': 'Invalid JSON'}, 400

        start_str = data.get('start_date')
        end_str = data.get('end_date')

        if not start_str or not end_str:
            return {'error': 'start_date and end_date are required'}, 400

        try:
            start = datetime.datetime.strptime(start_str, '%Y-%m-%d')
            end = datetime.datetime.strptime(end_str, '%Y-%m-%d')
        except ValueError:
            return {'error': 'invalid date format'}, 400

        if end < start:
            end = start

        try:
            raw_items = _read_spec_csv(_spec_csv)
        except FileNotFoundError:
            return {'error': f'CSV not found: {_spec_csv}'}, 500

        daily = []
        weekly_by_day = {}
        monthly = []
        quarterly = []
        for rtype, title, desc in raw_items:
            try:
                itype, weekday = parse_interval(rtype)
            except ValueError as e:
                return {'error': str(e)}, 400
            if itype == 'd':
                daily.append((title, desc))
            elif itype == 'w':
                weekly_by_day.setdefault(weekday, []).append((title, desc))
            elif itype == 'm':
                monthly.append((title, desc))
            elif itype == 'q':
                quarterly.append((title, desc))

        week_dates_by_day = {
            day: set(_all_weeks_on_day(start, end, day))
            for day in weekly_by_day
        }
        month_sundays = set(_first_sundays_of_month(start, end))
        quarter_sundays = set(_first_sundays_of_quarter(start, end))

        def generate():
            current = start
            while current <= end:
                label = current.strftime('%Y-%m-%d')
                due = list(daily)
                for day, specs in weekly_by_day.items():
                    if current in week_dates_by_day[day]:
                        due += specs
                if current in month_sundays:
                    due += monthly
                if current in quarter_sundays:
                    due += quarterly

                if not due:
                    yield f'data: {json.dumps({"date": label, "tasks": [], "status": "skip"})}\n\n'
                    current += datetime.timedelta(days=1)
                    continue

                try:
                    existing_names = {t.name for t in mgr.getTasks(date=current, start_date=current)}
                except Exception as exc:
                    yield f'data: {json.dumps({"date": label, "tasks": [], "status": "error", "message": str(exc)})}\n\n'
                    current += datetime.timedelta(days=1)
                    continue

                uploaded = []
                errors = []
                for title, desc in due:
                    if title in existing_names:
                        continue
                    try:
                        mgr.putTask(title, desc, current)
                        uploaded.append(title)
                    except Exception as exc:
                        errors.append(str(exc))

                if errors:
                    event = json.dumps({'date': label, 'tasks': uploaded, 'status': 'error', 'message': '; '.join(errors)})
                else:
                    event = json.dumps({'date': label, 'tasks': uploaded, 'status': 'ok'})
                yield f'data: {event}\n\n'
                current += datetime.timedelta(days=1)
            yield 'data: {"done": true}\n\n'

        return Response(stream_with_context(generate()), mimetype='text/event-stream')

    app.register_blueprint(bp)

    @app.route(f'{subdomain}/static/<path:filename>')
    def custom_static(filename):
        return app.send_static_file(filename)

    return app


def run():
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=5959)
    parser.add_argument('--subdomain', type=str, default='/tasks')
    parser.add_argument('--spec-csv', type=str, default='~/configs/intervaled-tasks.csv')
    args = parser.parse_args()

    app = create_app(subdomain=args.subdomain, spec_csv=args.spec_csv)
    app.secret_key = os.urandom(24)
    app.run(host='0.0.0.0', port=args.port, debug=False)


if __name__ == '__main__':
    run()
