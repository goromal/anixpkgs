{ buildPythonPackage
, flask
, abc
, mp3
, strings
, redirects
, writeTextFile
, callPackage
, writeShellScript
, python
}:
callPackage ../builders/mkSimpleFlaskApp.nix {
    pname = "flask_smfserver";
    version = "0.0.1";
    inherit buildPythonPackage flask writeTextFile writeShellScript python;
    scriptPropagatedBuildInputs = [];
    flaskScript = ''
        from subprocess import Popen, PIPE
        import tempfile, os, shutil

        mp3name = None
        smftext = "# SMF song here."
        tmpdir = None

        @app.route('/audio', methods=['GET','POST'])
        def test():
            global mp3name
            global smftext
            global tmpdir
            if flask.request.method == 'POST':
                if tmpdir is not None:
                    shutil.rmtree(tmpdir)
                smftext = flask.request.form['text']
                tmpdir = tempfile.mkdtemp()
                fname = "_textfile.smf"
                with open(os.path.join(tmpdir, fname), "w") as smffile:
                    smffile.write(smftext)
                p = Popen([helper_script, tmpdir, fname], stdout=PIPE, stderr=PIPE)
                mp3name, _ = p.communicate()
                mp3name = mp3name.decode("utf-8").strip()
                print('Operation complete.')
            
            if not mp3name is None:
                if "FAILED" in mp3name:
                    return flask.render_template('index.html', prog_output=mp3name, text_content=smftext)
                else:
                    return flask.send_file(mp3name, download_name=os.path.basename(mp3name))
    '';
    templateText = ''
        <!DOCTYPE html>
        <html>
        <head>
            <title>SMF Server</title>
        </head>
        <body>
            <h1>SMF Server</h1>
            <ul>
                <li>Assumed to be 4th octave unless a number is given <em>after</em> the letter.</li>
                <li>Assumed to be quarter note unless a number is given <em>before</em> the <em>group of</em> letters:
                    <ul>
                        <li>/3</li>
                        <li>/2</li>
                        <li>2</li>
                        <li>4</li>
                    </ul>
                </li>
                <li>Accidentals <em>immediately after</em> a letter:
                    <ul>
                        <li>^ = sharp</li>
                        <li>_ = flat</li>
                    </ul>
                </li>
                <li>- = rest</li>
                <li>Multiple letters in a group for a chord.</li>
                <li>1: or 2: or ...etc. for voice #.</li>
            </ul>
            <form action="/audio" method="POST">
                <textarea id="text" name="text" rows="20" cols="50">{{ text_content }}</textarea>
                <br><br>
                <input type="submit" value="Submit!">
            </form>
            <p>{{ prog_output }}</p>
        </body>
        </html>
    '';
    helperScript = ''
        cd "$1"
        smffile="$2"
        abc_msg=$(${abc}/bin/abc $smffile _midfile.abc | sed -n 2p)
        if [[ "$abc_msg" == *FAIL* ]]; then
            echo "$abc_msg"
            exit
        fi
        ${mp3}/bin/mp3 _midfile.abc out.mp3 ${redirects.suppress_all}
        echo "$PWD/out.mp3"
    '';
    description = "Spawn an SMF \"simple music file\" conversion server, powered by Python's flask library.";
    longDescription = ''
    ```bash
    usage: flask_smfserver [-h] [--port PORT]

    optional arguments:
    -h, --help   show this help message and exit
    --port PORT  Port to run the server on
    ```

    The server page presents a text input area where you can type a song as specified by the simplified SMF music specification language:

    - Notes are typed as letters with spaces between them.
    - All notes are assumed to be the 4th octave unless a number is given *after* the letter.
    - All notes are assumed to be quarter notes unless a number (multiplier) is given *before* the letter (or group of letters):
      - /3
      - /2
      - 2
      - 4
    - Accidentals are typed *immediately after a letter*:
      - ^ = sharp
      - _ = flat
    - The dash (-) means a rest. Use it like a letter.
    - Multiple letters in a group form a chord.
    - Begin a line with a number and colon (e.g., 1:) to specify a unique voice.

    Under the hood, conversions to MP3 are done using the [abc](../misc/abc.md) and [mp3](../misc/mp3.md) tools.
    '';
}
