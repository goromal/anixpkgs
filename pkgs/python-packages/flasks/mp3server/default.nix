{ buildPythonPackage, flask, mp3, strings, redirects, writeTextFile, callPackage
, writeShellScript, python }:
callPackage ../builders/mkSimpleFlaskApp.nix {
  pname = "flask_mp3server";
  version = "0.0.0";
  inherit buildPythonPackage flask writeTextFile writeShellScript python;
  scriptPropagatedBuildInputs = [ ];
  flaskScript = ''
    from subprocess import Popen, PIPE
    import tempfile, os

    mp3name = None

    @app.route('/audio', methods=['GET','POST'])
    def test():
        global mp3name
        if flask.request.method == 'POST':
            uploaded_file = flask.request.files['file']
            outn          = flask.request.form['outn']
            tran          = flask.request.form['tran']
            
            tmpdir = tempfile.mkdtemp()
            fname  = os.path.join(tmpdir, uploaded_file.filename)
            uploaded_file.save(fname)
            
            p = Popen([helper_script, tmpdir, uploaded_file.filename, outn, tran], stdout=PIPE, stderr=PIPE)
            mp3name, _ = p.communicate()
            mp3name = mp3name.decode("utf-8").strip()
            print('Operation complete.')
        
        if not mp3name is None:
            return flask.send_file(mp3name, download_name=os.path.basename(mp3name))
  '';
  templateText = ''
    <!DOCTYPE html>
    <html>
    <head>
        <title>MP3 Server</title>
    </head>
    <body>
        <h1>MP3 Server</h1>
        <form action="/audio" enctype="multipart/form-data" method="POST">
            <input type="file" name="file"><br>
            <label>Output mp3 name:
                <input type="text" name="outn" value="audio">
            </label><br>
            <label>Transpose:
                <input type="text" name="tran">
            </label><br><br>
            <input type="submit" value="Submit!">
            <input type="reset" value="Reset">
        </form>
    </body>
    </html>
  '';
  helperScript = ''
    cd "$1"
    infile="$2"
    outfilefull="$3"
    tran="$4"

    cmdargs=""

    if [[ "$tran" != "" ]]; then
        cmdargs="$cmdargs --transpose $tran"
    fi

    outfile=`${strings.getWithoutExtension} "$outfilefull"`
    cmdargs="$cmdargs $infile $outfile"
    ${mp3}/bin/mp3 $cmdargs ${redirects.suppress_all}
    echo "$PWD/$outfile.mp3"
  '';
  description =
    "Spawn an MP3 conversion server, powered by Python's flask library.";
  longDescription = ''
    The server page takes an input audio file and converts it to an MP3 using the [mp3](../bash/mp3.md) tool. One can also specify a frequency transpose in terms of positive or negative half-steps.
  '';
  autoGenUsageCmd = "--help";
}
