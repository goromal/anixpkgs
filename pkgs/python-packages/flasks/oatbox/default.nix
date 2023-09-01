{ buildPythonPackage, flask, writeTextFile, callPackage, writeShellScript
, python }:
callPackage ../builders/mkSimpleFlaskApp.nix {
  pname = "flask_oatbox";
  version = "0.0.0";
  inherit buildPythonPackage flask writeTextFile writeShellScript python;
  scriptPropagatedBuildInputs = [ ];
  overrideFullFlaskScript = true;
  flaskScript = ''
    import flask
    import argparse
    import os

    app = flask.Flask(__name__)

    takefile = None

    def get_status():
        if len([name for name in os.listdir('.') if os.path.isfile(name)]) > 0:
            return 'occupied'
        else:
            return 'vacant'

    def get_file():
        flist = [name for name in os.listdir('.') if os.path.isfile(name)] 
        if len(flist) > 0:
            return os.path.realpath(flist[0])
        else:
            return None

    def put_file(f):
        f_prev = get_file()
        if not f_prev is None:
            os.remove(f_prev)
        f.save(f.filename)

    @app.route('/', methods=['GET','POST'])
    def index():
        return flask.render_template('index.html', status=get_status())

    @app.route('/placebox', methods=['GET','POST'])
    def place():
        if flask.request.method == 'POST':    
            ufile = flask.request.files['file']
            put_file(ufile)
        return flask.render_template('index.html', status=get_status())

    @app.route('/takebox', methods=['GET','POST'])
    def take():
        global takefile
        if flask.request.method == 'POST':
            takefile = get_file()

        if not takefile is None:
            return flask.send_file(takefile, download_name=os.path.basename(takefile))

    def run():
        parser = argparse.ArgumentParser()
        parser.add_argument("--port", action="store", type=int, default=5000, help="Port to run the server on")
        args = parser.parse_args()
        app.run(host="0.0.0.0", port=args.port)
    if __name__ == "__main__":
        run()
  '';
  templateText = ''
    <!doctype html>
    <html>
      <head>
        <title>O.A.T. Box</title>
      </head>
      <body>
        <h1>O.A.T. Box</h1>

        {% if status %}
          <p>Box is currently {{status}}.</p>
        {% else %}
          <p>Box has unknown status.</p>
        {% endif %}

        <form method="POST" action="/placebox" enctype="multipart/form-data">
          <p><input type="file" name="file"></p>
          <p><input type="submit" value="Place"></p>
        </form>

        {% if status and status == 'occupied' %}
          <form method="POST" action="/takebox" enctype="multipart/form-data">
            <p><input type="submit" value="Take"></p>
          </form>
        {% endif %}

      </body>
    </html>
  '';
  description = ''
    "One at a time" (O.A.T.) Box. Store one file at a time, powered by Python's flask library.'';
  longDescription = ''
    ```bash
    usage: flask_oatbox [-h] [--port PORT]

    optional arguments:
      -h, --help   show this help message and exit
      --port PORT  Port to run the server on
    ```

    This tool gives you a method to store, extract, and replace files (again, one at a time) in the directory from which the tool is run.
  '';
}
