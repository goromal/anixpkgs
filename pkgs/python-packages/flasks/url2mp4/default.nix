{ buildPythonPackage, flask, mp4, yt-dlp, strings, redirects, wget-pkg
, writeTextFile, callPackage, writeShellScript, python }:
callPackage ../builders/mkSimpleFlaskApp.nix {
  pname = "flask_url2mp4";
  version = "0.0.0";
  inherit buildPythonPackage flask writeTextFile writeShellScript python;
  scriptPropagatedBuildInputs = [ ];
  flaskScript = ''
    from subprocess import Popen, PIPE
    import tempfile, shutil

    vidname = None
    tmpdir = None

    @app.route('/video', methods=['GET','POST'])
    def test():
        global vidname
        global tmpdir
        if flask.request.method == 'POST':
            if tmpdir is not None:
                shutil.rmtree(tmpdir)
            url = flask.request.form['text']
            tmpdir = tempfile.mkdtemp()
            p = Popen([helper_script, url, tmpdir], stdout=PIPE, stderr=PIPE)
            vidname, _ = p.communicate()
            vidname = vidname.decode("utf-8").strip()
            print('Operation complete.')
        
        if not vidname is None:
            return flask.send_file(vidname, download_name=os.path.basename(vidname))
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
    cd "$2"
    if [[ "$url" == *"yout"* ]]; then
        fname=video
        ${yt-dlp}/bin/yt-dlp -o $fname.mp4 -f mp4 "$url" ${redirects.suppress_all}
    else
        filename=`${strings.getBasename} "$url"`
        fname=`${strings.getWithoutExtension} "$filename"`
        ${wget-pkg}/bin/wget "$url" > wgetout 2>&1 # ${redirects.suppress_all}
        ${mp4}/bin/mp4 "$filename" "$fname" > mp4out 2>&1 # ${redirects.suppress_all}
    fi
    echo "$PWD/$fname.mp4"
  '';
  description =
    "Convert URL's pointing to videos to MP4's, powered by Python's flask library.";
  longDescription = ''
    The server page takes a URL string and either uses `wget` or `yt-dlp` to download the video and convert it to MP4 using the [mp4](../bash/mp4.md) tool.
  '';
  autoGenUsageCmd = "--help";
}
