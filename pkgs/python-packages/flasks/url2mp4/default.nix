{ buildPythonApplication
, flask
, mp4
, youtube-dl
, strings
, redirects
, writeTextFile
, callPackage
, writeShellScript
, python
}:
callPackage ../builders/mkSimpleFlaskApp.nix {
    pname = "flask_url2mp4";
    version = "0.0.0";
    inherit buildPythonApplication flask writeTextFile writeShellScript python;
    scriptPropagatedBuildInputs = [];
    flaskScript = ''
        from subprocess import Popen, PIPE

        vidname = None

        @app.route('/video', methods=['GET','POST'])
        def test():
            global vidname
            if flask.request.method == 'POST':
                url = flask.request.form['text']
                p = Popen([helper_script, url], stdout=PIPE, stderr=PIPE)
                vidname, _ = p.communicate()
                vidname = vidname.decode("utf-8").strip()
                print('Operation complete.')
            
            if not vidname is None:
                return flask.send_file(vidname, attachment_filename=os.path.basename(vidname))
    '';
    templateText = ''
        <!DOCTYPE html>
        <html>
        <body>
        <h1>Welcome</h1>
        <form action="/video" method="POST">
        <input type="text" name="text"><br><br>
        <input type="submit" value="Submit!">
        <input type="reset" value="Reset">
        </form>
        </body>
        </html>
    '';
    helperScript = ''
        url="$1"
        if [ -z "$url" ]; then
            url=http://dl5.webmfiles.org/big-buck-bunny_trailer.webm
        fi
        cd $(mktemp -d)
        if [[ "$url" == *"yout"* ]]; then
            fname=video
            ${youtube-dl}/bin/youtube-dl -o $fname.mp4 -f mp4 "$url" ${redirects.suppress_all}
        else
            filename=`${strings.getBasename} "$url"`
            fname=`${strings.getWithoutExtension} "$url"`
            wget "$url" ${redirects.suppress_all}
            ${mp4} "$filename" "$fname" ${redirects.suppress_all}
        fi
        echo "$PWD/$fname.mp4"
    '';
}
