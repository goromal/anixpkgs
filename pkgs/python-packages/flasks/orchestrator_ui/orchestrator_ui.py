import argparse
import os
import subprocess

import grpc
from aapis.orchestrator.v1 import orchestrator_pb2, orchestrator_pb2_grpc
from flask import (
    Flask, Blueprint, render_template, Response,
    stream_with_context, jsonify
)

parser = argparse.ArgumentParser()
parser.add_argument("--port", type=int, default=5000)
parser.add_argument("--subdomain", type=str, default="")
parser.add_argument("--services", type=str, default="",
                    help="Slash-separated list of service names")
parser.add_argument("--orch-port", type=int, default=40040,
                    help="orchestratord gRPC port")
parser.add_argument("--blacklist-dir", type=str, default="",
                    help="Directory of job-name marker files that blacklist jobs")
args = parser.parse_args()

services = [s for s in args.services.split("/") if s]

# Map each service unit ("<job>.service") to its bare job name, which is what
# the on-disk blacklist marker files and the orchestrator guard use.
JOB_NAMES = {svc: svc[:-len(".service")] if svc.endswith(".service") else svc
             for svc in services}

app = Flask(__name__)
bp = Blueprint('orchestrator', __name__, url_prefix=args.subdomain)

JOB_STATUS_NAMES = {
    0: "unspecified",
    1: "invalid",
    2: "complete",
    3: "queued",
    4: "active",
    5: "error",
    6: "blocked",
    7: "paused",
    8: "canceled",
}


def grpc_stub():
    channel = grpc.insecure_channel(f"localhost:{args.orch_port}")
    return orchestrator_pb2_grpc.OrchestratorServiceStub(channel)


def get_service_state(service):
    result = subprocess.run(
        ['systemctl', 'is-active', service],
        capture_output=True, text=True
    )
    return result.stdout.strip()


def get_service_info(service):
    result = subprocess.run(
        ['systemctl', 'show', service,
         '--property=ActiveEnterTimestamp,ExecMainExitTimestamp,ActiveState,SubState,Result'],
        capture_output=True, text=True
    )
    props = {}
    for line in result.stdout.strip().splitlines():
        if '=' in line:
            k, v = line.split('=', 1)
            props[k] = v
    return props


@bp.route('/')
def index():
    statuses = {svc: get_service_state(svc) for svc in services}
    orch_state = get_service_state('orchestratord')
    return render_template('main.html', services=services, statuses=statuses,
                           orch_state=orch_state, subdomain=args.subdomain,
                           job_names=JOB_NAMES)


@bp.route('/status/<service>')
def status(service):
    if service not in services:
        return jsonify({'error': 'Invalid service'}), 400
    props = get_service_info(service)
    return jsonify({
        'service': service,
        'state': props.get('ActiveState', 'unknown'),
        'sub_state': props.get('SubState', 'unknown'),
        'result': props.get('Result', 'unknown'),
        'active_since': props.get('ActiveEnterTimestamp', ''),
        'last_exit': props.get('ExecMainExitTimestamp', ''),
    })


@bp.route('/restart/<service>', methods=['POST'])
def restart(service):
    if service not in services:
        return jsonify({'error': 'Invalid service'}), 400

    def generate():
        proc = subprocess.Popen(
            ['systemctl', 'restart', service],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True
        )
        for line in proc.stdout:
            yield f"data: {line.rstrip()}\n\n"
        proc.wait()
        if proc.returncode == 0:
            yield "data: [Restart successful]\n\n"
        else:
            yield f"data: [Restart failed with exit code {proc.returncode}]\n\n"
        yield "data: [DONE]\n\n"

    return Response(stream_with_context(generate()), mimetype='text/event-stream')


def blacklist_marker(job_name):
    """Absolute path to a job's blacklist marker, or None if invalid/unconfigured."""
    if not args.blacklist_dir or job_name not in JOB_NAMES.values():
        return None
    return os.path.join(args.blacklist_dir, job_name)


@bp.route('/jobs/blacklist')
def blacklist_status():
    """Return {job_name: blacklisted_bool} for every known job."""
    return jsonify({
        name: (marker is not None and os.path.exists(marker))
        for name, marker in (
            (n, blacklist_marker(n)) for n in JOB_NAMES.values()
        )
    })


@bp.route('/jobs/blacklist/<job_name>', methods=['POST', 'DELETE'])
def blacklist_toggle(job_name):
    from flask import request
    marker = blacklist_marker(job_name)
    if marker is None:
        return jsonify({'error': 'Unknown job or blacklist not configured'}), 400
    try:
        if request.method == 'POST':
            os.makedirs(args.blacklist_dir, exist_ok=True)
            with open(marker, 'w'):
                pass
        else:
            if os.path.exists(marker):
                os.remove(marker)
    except OSError as e:
        return jsonify({'error': str(e)}), 500
    return jsonify({'job': job_name, 'blacklisted': os.path.exists(marker)})


@bp.route('/jobs/summary')
def jobs_summary():
    try:
        stub = grpc_stub()
        resp = stub.JobsSummaryStatus(
            orchestrator_pb2.JobsSummaryStatusRequest(),
            timeout=5
        )
        return jsonify({
            'active': list(resp.active_jobs),
            'queued': list(resp.queued_jobs),
            'blocked': list(resp.blocked_jobs),
            'paused': list(resp.paused_jobs),
            'completed': list(resp.completed_jobs),
            'discarded': list(resp.discarded_jobs),
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 503


@bp.route('/jobs/<int:job_id>')
def job_detail(job_id):
    try:
        stub = grpc_stub()
        resp = stub.JobStatus(
            orchestrator_pb2.JobStatusRequest(job_id=job_id),
            timeout=5
        )
        return jsonify({
            'job_id': job_id,
            'status': JOB_STATUS_NAMES.get(resp.status, str(resp.status)),
            'exec': resp.exec,
            'priority': resp.priority,
            'blockers': list(resp.blockers),
            'outputs': list(resp.outputs),
            'spawned_children': list(resp.spawned_children),
            'message': resp.message,
            'program_output': resp.program_output,
            'exec_duration_secs': resp.exec_duration_secs,
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 503


@bp.route('/status-orchestratord')
def status_orchestratord():
    return jsonify({'state': get_service_state('orchestratord')})


@bp.route('/stop-orchestratord', methods=['POST'])
def stop_orchestratord():
    def generate():
        proc = subprocess.Popen(
            ['systemctl', 'stop', 'orchestratord'],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True
        )
        for line in proc.stdout:
            yield f"data: {line.rstrip()}\n\n"
        proc.wait()
        if proc.returncode == 0:
            yield "data: [Stop successful]\n\n"
        else:
            yield f"data: [Stop failed with exit code {proc.returncode}]\n\n"
        yield "data: [DONE]\n\n"

    return Response(stream_with_context(generate()), mimetype='text/event-stream')


@bp.route('/start-orchestratord', methods=['POST'])
def start_orchestratord():
    def generate():
        proc = subprocess.Popen(
            ['systemctl', 'start', 'orchestratord'],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True
        )
        for line in proc.stdout:
            yield f"data: {line.rstrip()}\n\n"
        proc.wait()
        if proc.returncode == 0:
            yield "data: [Start successful]\n\n"
        else:
            yield f"data: [Start failed with exit code {proc.returncode}]\n\n"
        yield "data: [DONE]\n\n"

    return Response(stream_with_context(generate()), mimetype='text/event-stream')


@bp.route('/restart-orchestratord', methods=['POST'])
def restart_orchestratord():
    def generate():
        proc = subprocess.Popen(
            ['systemctl', 'restart', 'orchestratord'],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True
        )
        for line in proc.stdout:
            yield f"data: {line.rstrip()}\n\n"
        proc.wait()
        if proc.returncode == 0:
            yield "data: [orchestratord restarted]\n\n"
        else:
            yield f"data: [Restart failed with exit code {proc.returncode}]\n\n"
        yield "data: [DONE]\n\n"

    return Response(stream_with_context(generate()), mimetype='text/event-stream')


app.register_blueprint(bp)


def run():
    app.run(host='0.0.0.0', port=args.port, debug=False)


if __name__ == '__main__':
    run()
