{ buildPythonPackage
, flask
, mp4
, strings
, redirects
, writeTextFile
, callPackage
, writeShellScript
, python
}: # TODO change to flask_mp4server (just serves the API of mp4)
callPackage ../builders/mkSimpleFlaskApp.nix {
    pname = "flask_mp4server";
    version = "0.0.0";
    inherit buildPythonPackage flask writeTextFile writeShellScript python;
    scriptPropagatedBuildInputs = [];
    flaskScript = ''
        from subprocess import Popen, PIPE
        import tempfile, os

        vidname = None

        @app.route('/video', methods=['GET','POST'])
        def test():
            global vidname
            if flask.request.method == 'POST':
                uploaded_file = flask.request.files['file']
                tmpdir = tempfile.mkdtemp()
                fname = os.path.join(tmpdir, uploaded_file.filename)
                uploaded_file.save(fname)
                p = Popen([helper_script, tmpdir], stdout=PIPE, stderr=PIPE)
                vidname, _ = p.communicate()
                vidname = vidname.decode("utf-8").strip()
                print('Operation complete.')
            
            if not vidname is None:
                return flask.send_file(vidname, attachment_filename=os.path.basename(vidname))
    '';
    templateText = ''
        <!doctype html>
        <html>
        <head>
            <title>MP4 Server</title>
        </head>
        <body>
            <h1>MP4 Server</h1>
            <form method="POST" action="/video" enctype="multipart/form-data">
            <p><input type="file" name="file"></p>
            <p><input type="submit" value="Submit"></p>
            </form>
        </body>
        </html>
    '';
    helperScript = ''
        cd "$1"
        vidfile="$(ls)"
        vidname=`${strings.getWithoutExtension} "$vidfile"`
        ${mp4} "$vidfile" "$vidname" ${redirects.suppress_all}
        echo "$PWD/$vidname.mp4"
    '';
}
