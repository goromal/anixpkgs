{ buildPythonPackage
, flask
, mp3
, strings
, redirects
, writeTextFile
, callPackage
, writeShellScript
, python
}:
callPackage ../builders/mkSimpleFlaskApp.nix {
    pname = "flask_mp3server";
    version = "0.0.0";
    inherit buildPythonPackage flask writeTextFile writeShellScript python;
    scriptPropagatedBuildInputs = [];
    flaskScript = ''
        from flask import send_file
        import os, tempfile, shutil
        from subprocess import Popen, PIPE

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
    return render_template('twowayfile.html', status=get_status())

@app.route('/placebox', methods=['GET','POST'])
def place():
    if request.method == 'POST':    
        ufile = request.files['file']
        put_file(ufile)
    return render_template('twowayfile.html', status=get_status())

@app.route('/takebox', methods=['GET','POST'])
def take():
    global takefile
    if request.method == 'POST':
        takefile = get_file()

    if not takefile is None:
        return send_file(takefile, attachment_filename=os.path.basename(takefile))

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
    helperScript = "";
}
