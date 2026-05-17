import argparse
import datetime
import json
import os

from flask import Flask, Blueprint, request, render_template, Response, stream_with_context


def _init_manager():
    from task_tools.manage import TaskManager
    try:
        return TaskManager(), None
    except Exception as e:
        return None, str(e)


def create_app(subdomain='', manager=None):
    app = Flask(__name__)
    bp = Blueprint('tasks', __name__, url_prefix=subdomain)

    @bp.route('/', methods=['GET'])
    def index():
        return render_template('main.html')

    @bp.route('/submit', methods=['POST'])
    def submit():
        if manager is None:
            return {'error': 'TaskManager not initialized — check secrets'}, 500

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
                    manager.putTask(name, notes, current)
                    event = json.dumps({'date': label, 'status': 'ok'})
                except Exception as exc:
                    event = json.dumps({'date': label, 'status': 'error', 'message': str(exc)})
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
    args = parser.parse_args()

    manager, err = _init_manager()
    if manager is None:
        print(f'Warning: TaskManager init failed: {err}', flush=True)

    app = create_app(subdomain=args.subdomain, manager=manager)
    app.secret_key = os.urandom(24)
    app.run(host='0.0.0.0', port=args.port, debug=False)


if __name__ == '__main__':
    run()
