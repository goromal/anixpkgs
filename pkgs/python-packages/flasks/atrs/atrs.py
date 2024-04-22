import argparse
from flask import Flask, request, jsonify
from werkzeug.security import check_password_hash

parser = argparse.ArgumentParser()
parser.add_argument("--port", action="store", type=int, default=5000, help="Port to run the REST server on")
args = parser.parse_args()

app = Flask(__name__)

@app.route('/test', methods=['GET','POST'])
def api():
    if check_password_hash("pbkdf2:sha256:260000$lZSRuIMsXegmiXNl$8a1fde09226a09391218ec3b1f07f6d8373a055f0469b69d0855f9cc29a53e31", request.args.get('key')):
        return jsonify({'message': f'Success! Key is valid. You sent {request.args.get("payload")}'}), 200
    else:
        return jsonify({'error': 'Invalid key provided.'}), 401

def run():
    global args
    app.run(host="0.0.0.0", port = args.port)

if __name__ == '__main__':
    run()
