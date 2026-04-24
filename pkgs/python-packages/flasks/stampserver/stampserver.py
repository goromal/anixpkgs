import os
import re
import shutil
import subprocess
import argparse
import flask
import flask_login
import flask_wtf
from wtforms import StringField, PasswordField, SubmitField
from werkzeug.security import check_password_hash
from random import shuffle
from datetime import timedelta
from PIL import Image
import cv2

STAMP_RE = re.compile(r"stamped\.(.*?)\.")

parser = argparse.ArgumentParser()
parser.add_argument("--port", action="store", type=int, default=5000, help="Port to run the server on")
parser.add_argument("--subdomain", action="store", type=str, default="/", help="Subdomain for a reverse proxy")
parser.add_argument("--data-dir", action="store", type=str, default="", help="Directory containing the stampable elements")
args = parser.parse_args()

urlroot = args.subdomain
if urlroot != "/":
    urlroot += "/"
url_for_prefix = args.subdomain.replace("/", "")
if len(url_for_prefix) > 0:
    url_for_prefix += "."

bp = flask.Blueprint("stamp", __name__, url_prefix=args.subdomain)

class LoginForm(flask_wtf.FlaskForm):
    username = StringField("Username")
    password = PasswordField("Password")
    submit = SubmitField("Submit")

class User(flask_login.UserMixin):
    def check_password(self, password):
        return check_password_hash("scrypt:32768:8:1$acPu0meyxPfx0SnS$26a570af250e0593c2dbb6bfb1d037a7366109a0ba4886e68191237efdabb2fca07de6c81c337b5e275390c2d7ff96f3455f47b7a05027a7e0ebf1628f537498", password)
    def get_id(self):
        return "anonymous"

user = User()

PWD = os.getcwd()
if args.data_dir[0] == '/':
    RES_DIR = args.data_dir
else:
    RES_DIR = os.path.join(PWD, args.data_dir)
SHORT_RESDIR = os.path.basename(os.path.realpath(RES_DIR))

app = flask.Flask(__name__, static_url_path=args.subdomain, static_folder=RES_DIR)
app.secret_key = b"71d2dcdb895b367a1d5f0c66ca559c8d69af0c29a7e101c18c7c2d10399f264e"
app.config["PERMANENT_SESSION_LIFETIME"] = timedelta(minutes=20)
login_manager = flask_login.LoginManager()

class StampServer:
    STAMP = "asdfkl;ajsd;lkfj;ljkasdf"
    
    def __init__(self):
        self.reset()
        self.task_type = StampServer.STAMP

    def reset(self):
        self.filelist = []
        self.filedeck = ""

    def load(self):
        if not os.path.isdir(RES_DIR):
            return (False, f"Data directory non-existent or broken: {RES_DIR}")
        if self.task_type != StampServer.STAMP:
            self.reset()
            self.task_type = StampServer.STAMP
        if len(self.filelist) == 0:
            for file in os.listdir(RES_DIR):
                if file.startswith("stamped."):
                    continue
                if file.lower().endswith(".png"):
                    self.filelist.append((file.strip(), "PNG"))
                elif file.lower().endswith(".mp4"):
                    self.filelist.append((file.strip(), "MP4"))
            shuffle(self.filelist)
        if len(self.filelist) == 0:
            return (False, f"Data directory devoid of stampable files!")
        return (True, "")

    def load_stamped(self, stamp):
        if not os.path.isdir(RES_DIR):
            return (False, f"Data directory non-existent or broken: {RES_DIR}")
        if self.task_type != stamp:
            self.reset()
            self.task_type = stamp
        if len(self.filelist) == 0:
            for file in os.listdir(RES_DIR):
                if file.startswith(f"stamped.{stamp}."):
                    if file.lower().endswith(".png"):
                        self.filelist.append((file.strip(), "PNG"))
                    elif file.lower().endswith(".mp4"):
                        self.filelist.append((file.strip(), "MP4"))
            shuffle(self.filelist)
        if len(self.filelist) == 0:
            return (False, f"Data directory devoid of files stamped with {stamp}!")
        return (True, "")
    
    def getfile(self):
        for file, ftype in self.filelist:
            self.filedeck = file
            return file, ftype, len(self.filelist)
    
    def getstamps(self):
        stamps = {}
        for file in os.listdir(RES_DIR):
            m = STAMP_RE.search(file)
            if m:
                key = m.group(1)
                stamps[key] = stamps.get(key, 0) + 1
        return dict(sorted(stamps.items(), key=lambda x: x[1], reverse=True))

    def stamp(self, stamp):
        dirname = RES_DIR
        basename = os.path.basename(self.filedeck)
        os.rename(os.path.join(dirname, self.filedeck), os.path.join(dirname, f"stamped.{stamp}." + basename))
        self.filelist = list(filter(lambda t: t[0] != self.filedeck, self.filelist))

    def replace_stamp(self, stamp, new_stamp):
        dirname = RES_DIR
        basename = os.path.basename(self.filedeck)
        # Validate that the file has the expected stamp prefix format
        if not basename.startswith(f"stamped.{stamp}."):
            raise ValueError(f"File {basename} does not have expected stamp prefix 'stamped.{stamp}.'")
        # Remove the old stamp prefix and add the new one
        remainder = basename[len(f"stamped.{stamp}."):]
        new_basename = f"stamped.{new_stamp}.{remainder}"
        os.rename(os.path.join(dirname, self.filedeck), os.path.join(dirname, new_basename))
        self.filelist = list(filter(lambda t: t[0] != self.filedeck, self.filelist))

stampserver = StampServer()

@login_manager.user_loader
def load_user(user_id):
    global user
    if user_id == "anonymous":
        return user
    else:
        return None
      
@bp.route("/login", methods=["GET", "POST"])
def login():
    global user
    global url_for_prefix
    global urlroot
    if flask_login.current_user.is_authenticated:
        return flask.redirect(flask.url_for(url_for_prefix + 'index'))
    form = LoginForm()
    if form.validate_on_submit():
        if form.username.data == "admin":
            return flask.redirect("/grafana")
        if form.username.data != user.get_id() or not user.check_password(form.password.data):
            return flask.redirect(flask.url_for(url_for_prefix + "login"))
        flask_login.login_user(user, remember=False)
        flask.session.permanent = True
        return flask.render_template(
            "index.html",
            urlroot=urlroot,
            err=False,
            msg="",
            file="https://github.com/goromal/anixdata/raw/master/data/media/scrape-tests/sample_640x360.mp4",
            ftype="MP4_EXT",
            root="zzz",
            nleft="?",
            datadir=SHORT_RESDIR,
            stamps={}
        )
    return flask.render_template("login.html", title="Sign In", form=form)
      
@bp.route("/logout")
@flask_login.login_required
def logout():
    global url_for_prefix
    flask_login.logout_user()
    return flask.redirect(flask.url_for(url_for_prefix + "login"))

@bp.route("/", methods=["GET","POST"])
@flask_login.login_required
def index():
    global args
    global stampserver
    global urlroot
    if flask.request.method == "POST":
        if flask.request.form["text"] != "":
            stampserver.stamp(flask.request.form["text"])
    res, msg = stampserver.load()
    stamps = stampserver.getstamps()
    if not res:
        return flask.render_template("index.html", urlroot=urlroot, err=True, msg=msg, file="", ftype="", root="", nleft="?", datadir=SHORT_RESDIR, stamps=stamps)
    file, ftype, numleft = stampserver.getfile()
    file = urlroot + file
    return flask.render_template("index.html", urlroot=urlroot, err=False, msg="", file=file, ftype=ftype, root="", nleft=str(numleft), datadir=SHORT_RESDIR, stamps=stamps)

@bp.route("/restamp/", methods=["GET","POST"])
@bp.route("/restamp/<stamp>", methods=["GET","POST"])
@flask_login.login_required
def stamped(stamp=""):
    global args
    global stampserver
    global urlroot
    if flask.request.method == "POST":
        if flask.request.form["text"] == "":
            new_stamp = stamp
        else:
            new_stamp = flask.request.form["text"]
        stampserver.replace_stamp(stamp, new_stamp)
    res, msg = stampserver.load_stamped(stamp)
    if not res:
        return flask.render_template("index.html", urlroot=urlroot, err=True, msg=msg, file="", ftype="", root=f"restamp/{stamp}", nleft="?", datadir=SHORT_RESDIR, stamps={})
    file, ftype, numleft = stampserver.getfile()
    file = urlroot + file
    return flask.render_template("index.html", urlroot=urlroot, err=False, msg="", file=file, ftype=ftype, root=f"restamp/{stamp}", nleft=str(numleft), datadir=SHORT_RESDIR, stamps={})

@bp.route("/zzz", methods=["GET","POST"])
@flask_login.login_required
def zzz():
    global urlroot
    return flask.render_template(
        "index.html",
        urlroot=urlroot,
        err=False,
        msg="",
        file="https://github.com/goromal/anixdata/raw/master/data/media/scrape-tests/sample_640x360.mp4",
        ftype="MP4_EXT",
        root="zzz",
        nleft="?",
        datadir=SHORT_RESDIR,
        stamps={}
    )

@bp.route("/api/rotate-image", methods=["POST"])
@flask_login.login_required
def rotate_image_api():
    try:
        data = flask.request.get_json()
        filename = data.get('filename')
        degrees = data.get('degrees')

        if not filename or degrees is None:
            return flask.jsonify({'success': False, 'error': 'Missing filename or degrees parameter'}), 400

        # Construct full file path
        file_path = os.path.join(RES_DIR, filename)

        # Validate file exists and is a PNG
        if not os.path.exists(file_path):
            return flask.jsonify({'success': False, 'error': f'File not found: {filename}'}), 404

        if not filename.lower().endswith('.png'):
            return flask.jsonify({'success': False, 'error': 'Only PNG files can be rotated'}), 400

        # Open image with Pillow
        img = Image.open(file_path)

        # Rotate image (Pillow uses counter-clockwise rotation, so we negate)
        # Also, convert degrees to the format Pillow expects
        if degrees == 90:
            rotated_img = img.rotate(-90, expand=True)
        elif degrees == 270:
            rotated_img = img.rotate(90, expand=True)
        elif degrees == 180:
            rotated_img = img.rotate(180, expand=True)
        else:
            rotated_img = img.rotate(-degrees, expand=True)

        # Save to temporary file first, then rename (atomic operation)
        temp_path = file_path + '.tmp'
        rotated_img.save(temp_path, format='PNG')
        os.replace(temp_path, file_path)

        return flask.jsonify({'success': True})

    except Exception as e:
        return flask.jsonify({'success': False, 'error': str(e)}), 500

@bp.route("/api/crop-image", methods=["POST"])
@flask_login.login_required
def crop_image_api():
    try:
        data = flask.request.get_json()
        filename = data.get('filename')
        x = data.get('x')
        y = data.get('y')
        width = data.get('width')
        height = data.get('height')

        if not filename or x is None or y is None or width is None or height is None:
            return flask.jsonify({'success': False, 'error': 'Missing required parameters'}), 400

        # Construct full file path
        file_path = os.path.join(RES_DIR, filename)

        # Validate file exists and is a PNG
        if not os.path.exists(file_path):
            return flask.jsonify({'success': False, 'error': f'File not found: {filename}'}), 404

        if not filename.lower().endswith('.png'):
            return flask.jsonify({'success': False, 'error': 'Only PNG files can be cropped'}), 400

        # Validate crop parameters
        if width <= 0 or height <= 0:
            return flask.jsonify({'success': False, 'error': 'Width and height must be positive'}), 400

        # Open image with Pillow
        img = Image.open(file_path)
        img_width, img_height = img.size

        # Validate crop bounds
        if x < 0 or y < 0 or x + width > img_width or y + height > img_height:
            return flask.jsonify({'success': False, 'error': f'Crop bounds exceed image dimensions ({img_width}x{img_height})'}), 400

        # Crop image (box is left, upper, right, lower)
        cropped_img = img.crop((x, y, x + width, y + height))

        # Save to temporary file first, then rename (atomic operation)
        temp_path = file_path + '.tmp'
        cropped_img.save(temp_path, format='PNG')
        os.replace(temp_path, file_path)

        return flask.jsonify({'success': True})

    except Exception as e:
        return flask.jsonify({'success': False, 'error': str(e)}), 500

@bp.route("/api/duplicate-image", methods=["POST"])
@flask_login.login_required
def duplicate_image_api():
    try:
        data = flask.request.get_json()
        filename = data.get('filename')

        if not filename:
            return flask.jsonify({'success': False, 'error': 'Missing filename parameter'}), 400

        # Construct full file path
        file_path = os.path.join(RES_DIR, filename)

        # Validate file exists and is a PNG
        if not os.path.exists(file_path):
            return flask.jsonify({'success': False, 'error': f'File not found: {filename}'}), 404

        if not filename.lower().endswith('.png'):
            return flask.jsonify({'success': False, 'error': 'Only PNG files can be duplicated'}), 400

        # Parse filename to preserve stamp metadata
        # Format: [stamped.{stamp}.]basename.png
        base_name = os.path.splitext(filename)[0]
        extension = os.path.splitext(filename)[1]

        # Check if file has stamp metadata
        stamp_prefix = ""
        actual_base = base_name
        if base_name.startswith("stamped."):
            parts = base_name.split(".", 2)  # Split into ['stamped', '{stamp}', 'basename']
            if len(parts) >= 3:
                stamp_prefix = f"stamped.{parts[1]}."
                actual_base = parts[2]
            elif len(parts) == 2:
                stamp_prefix = f"stamped.{parts[1]}."
                actual_base = ""

        # Generate new filename with _copy suffix
        counter = 1
        while True:
            if counter == 1:
                new_basename = f"{actual_base}_copy"
            else:
                new_basename = f"{actual_base}_copy{counter}"

            new_filename = f"{stamp_prefix}{new_basename}{extension}"
            new_file_path = os.path.join(RES_DIR, new_filename)

            if not os.path.exists(new_file_path):
                break
            counter += 1

        # Copy the file using Pillow to ensure proper PNG handling
        img = Image.open(file_path)
        img.save(new_file_path, format='PNG')

        return flask.jsonify({'success': True, 'new_filename': new_filename})

    except Exception as e:
        return flask.jsonify({'success': False, 'error': str(e)}), 500

@bp.route("/api/save-screenshot", methods=["POST"])
@flask_login.login_required
def save_screenshot_api():
    try:
        data = flask.request.get_json()
        filename = data.get('filename')
        timestamp = data.get('timestamp')

        if not filename or timestamp is None:
            return flask.jsonify({'success': False, 'error': 'Missing filename or timestamp parameter'}), 400

        # Construct full file path
        file_path = os.path.join(RES_DIR, filename)

        # Validate file exists and is a video
        if not os.path.exists(file_path):
            return flask.jsonify({'success': False, 'error': f'File not found: {filename}'}), 404

        if not (filename.lower().endswith('.mp4') or filename.lower().endswith('.webm')):
            return flask.jsonify({'success': False, 'error': 'Only MP4 and WEBM files can have screenshots taken'}), 400

        # Open video with OpenCV
        cap = cv2.VideoCapture(file_path)

        if not cap.isOpened():
            return flask.jsonify({'success': False, 'error': 'Could not open video file'}), 500

        # Get video duration to validate timestamp
        fps = cap.get(cv2.CAP_PROP_FPS)
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        duration = total_frames / fps if fps > 0 else 0

        if timestamp < 0 or timestamp > duration:
            cap.release()
            return flask.jsonify({'success': False, 'error': f'Timestamp {timestamp}s is outside video duration (0-{duration:.2f}s)'}), 400

        # Seek to the specified timestamp
        cap.set(cv2.CAP_PROP_POS_MSEC, timestamp * 1000)

        # Read the frame
        ret, frame = cap.read()
        cap.release()

        if not ret:
            return flask.jsonify({'success': False, 'error': 'Could not read frame at specified timestamp'}), 500

        # Generate new filename
        base_name = os.path.splitext(filename)[0]
        new_filename = f"{base_name}_screenshot_{timestamp:.2f}.png"
        new_file_path = os.path.join(RES_DIR, new_filename)

        # Check if file already exists, add counter if needed
        counter = 1
        while os.path.exists(new_file_path):
            new_filename = f"{base_name}_screenshot_{timestamp:.2f}_{counter}.png"
            new_file_path = os.path.join(RES_DIR, new_filename)
            counter += 1

        # Save frame as PNG
        cv2.imwrite(new_file_path, frame)

        return flask.jsonify({'success': True, 'new_filename': new_filename})

    except Exception as e:
        return flask.jsonify({'success': False, 'error': str(e)}), 500

@bp.route("/api/duplicate-video", methods=["POST"])
@flask_login.login_required
def duplicate_video_api():
    try:
        data = flask.request.get_json()
        filename = data.get('filename')

        if not filename:
            return flask.jsonify({'success': False, 'error': 'Missing filename parameter'}), 400

        file_path = os.path.join(RES_DIR, filename)

        if not os.path.exists(file_path):
            return flask.jsonify({'success': False, 'error': f'File not found: {filename}'}), 404

        if not filename.lower().endswith('.mp4'):
            return flask.jsonify({'success': False, 'error': 'Only MP4 files can be duplicated'}), 400

        base_name = os.path.splitext(filename)[0]
        extension = os.path.splitext(filename)[1]

        stamp_prefix = ""
        actual_base = base_name
        if base_name.startswith("stamped."):
            parts = base_name.split(".", 2)
            if len(parts) >= 3:
                stamp_prefix = f"stamped.{parts[1]}."
                actual_base = parts[2]
            elif len(parts) == 2:
                stamp_prefix = f"stamped.{parts[1]}."
                actual_base = ""

        counter = 1
        while True:
            new_basename = f"{actual_base}_copy" if counter == 1 else f"{actual_base}_copy{counter}"
            new_filename = f"{stamp_prefix}{new_basename}{extension}"
            new_file_path = os.path.join(RES_DIR, new_filename)
            if not os.path.exists(new_file_path):
                break
            counter += 1

        shutil.copy2(file_path, new_file_path)
        return flask.jsonify({'success': True, 'new_filename': new_filename})

    except Exception as e:
        return flask.jsonify({'success': False, 'error': str(e)}), 500

@bp.route("/api/rotate-video", methods=["POST"])
@flask_login.login_required
def rotate_video_api():
    try:
        data = flask.request.get_json()
        filename = data.get('filename')
        degrees = data.get('degrees')

        if not filename or degrees is None:
            return flask.jsonify({'success': False, 'error': 'Missing filename or degrees parameter'}), 400

        file_path = os.path.join(RES_DIR, filename)

        if not os.path.exists(file_path):
            return flask.jsonify({'success': False, 'error': f'File not found: {filename}'}), 404

        if not filename.lower().endswith('.mp4'):
            return flask.jsonify({'success': False, 'error': 'Only MP4 files can be rotated'}), 400

        normalized = ((int(degrees) % 360) + 360) % 360
        if normalized == 90:
            vf = 'transpose=1'
        elif normalized == 270:
            vf = 'transpose=2'
        elif normalized == 180:
            vf = 'vflip,hflip'
        else:
            return flask.jsonify({'success': False, 'error': f'Unsupported rotation: {degrees}°'}), 400

        temp_path = file_path + '.tmp.mp4'
        result = subprocess.run(
            ['ffmpeg', '-i', file_path, '-vf', vf, '-c:a', 'copy', temp_path, '-y'],
            capture_output=True, text=True
        )

        if result.returncode != 0:
            if os.path.exists(temp_path):
                os.remove(temp_path)
            return flask.jsonify({'success': False, 'error': f'ffmpeg error: {result.stderr[-500:]}'}), 500

        os.replace(temp_path, file_path)
        return flask.jsonify({'success': True})

    except Exception as e:
        return flask.jsonify({'success': False, 'error': str(e)}), 500

@bp.route("/api/crop-video", methods=["POST"])
@flask_login.login_required
def crop_video_api():
    try:
        data = flask.request.get_json()
        filename = data.get('filename')
        x = data.get('x')
        y = data.get('y')
        width = data.get('width')
        height = data.get('height')

        if not filename or x is None or y is None or width is None or height is None:
            return flask.jsonify({'success': False, 'error': 'Missing required parameters'}), 400

        file_path = os.path.join(RES_DIR, filename)

        if not os.path.exists(file_path):
            return flask.jsonify({'success': False, 'error': f'File not found: {filename}'}), 404

        if not filename.lower().endswith('.mp4'):
            return flask.jsonify({'success': False, 'error': 'Only MP4 files can be cropped'}), 400

        if width <= 0 or height <= 0:
            return flask.jsonify({'success': False, 'error': 'Width and height must be positive'}), 400

        temp_path = file_path + '.tmp.mp4'
        result = subprocess.run(
            ['ffmpeg', '-i', file_path, '-vf', f'crop={width}:{height}:{x}:{y}',
             '-c:a', 'copy', temp_path, '-y'],
            capture_output=True, text=True
        )

        if result.returncode != 0:
            if os.path.exists(temp_path):
                os.remove(temp_path)
            return flask.jsonify({'success': False, 'error': f'ffmpeg error: {result.stderr[-500:]}'}), 500

        os.replace(temp_path, file_path)
        return flask.jsonify({'success': True})

    except Exception as e:
        return flask.jsonify({'success': False, 'error': str(e)}), 500

@bp.route("/api/trim-video", methods=["POST"])
@flask_login.login_required
def trim_video_api():
    try:
        data = flask.request.get_json()
        filename = data.get('filename')
        edit_points = data.get('edit_points', [])

        if not filename:
            return flask.jsonify({'success': False, 'error': 'Missing filename parameter'}), 400

        if not edit_points:
            return flask.jsonify({'success': False, 'error': 'No edit points provided'}), 400

        file_path = os.path.join(RES_DIR, filename)

        if not os.path.exists(file_path):
            return flask.jsonify({'success': False, 'error': f'File not found: {filename}'}), 404

        if not filename.lower().endswith('.mp4'):
            return flask.jsonify({'success': False, 'error': 'Only MP4 files can be trimmed'}), 400

        cap = cv2.VideoCapture(file_path)
        if not cap.isOpened():
            return flask.jsonify({'success': False, 'error': 'Could not open video file'}), 500
        fps = cap.get(cv2.CAP_PROP_FPS)
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        duration = total_frames / fps if fps > 0 else 0
        cap.release()

        pts = sorted(edit_points, key=lambda p: p['time'])

        if pts[0]['type'] == 'end':
            pts.insert(0, {'type': 'start', 'time': 0.0})
        if pts[-1]['type'] == 'start':
            pts.append({'type': 'end', 'time': duration})

        segments = []
        i = 0
        while i < len(pts) - 1:
            if pts[i]['type'] == 'start' and pts[i + 1]['type'] == 'end':
                segments.append((pts[i]['time'], pts[i + 1]['time']))
                i += 2
            else:
                return flask.jsonify({'success': False, 'error': f'Invalid edit point sequence at index {i}: expected alternating start/end pairs'}), 400

        if not segments:
            return flask.jsonify({'success': False, 'error': 'No valid segments formed from edit points'}), 400

        temp_path = file_path + '.tmp.mp4'

        # Detect whether the video has an audio stream
        probe = subprocess.run(
            ['ffprobe', '-v', 'quiet', '-select_streams', 'a',
             '-show_entries', 'stream=codec_type',
             '-of', 'default=noprint_wrappers=1', file_path],
            capture_output=True, text=True
        )
        has_audio = 'codec_type=audio' in probe.stdout

        # Build a single-pass filter_complex trim+concat (avoids intermediate files
        # and the stream-detection issues of the concat demuxer with stream copy).
        n = len(segments)
        filter_parts = []
        for i, (start, end) in enumerate(segments):
            filter_parts.append(f"[0:v]trim=start={start}:end={end},setpts=PTS-STARTPTS[v{i}]")
            if has_audio:
                filter_parts.append(f"[0:a]atrim=start={start}:end={end},asetpts=PTS-STARTPTS[a{i}]")

        if has_audio:
            stream_inputs = ''.join(f'[v{i}][a{i}]' for i in range(n))
            filter_parts.append(f"{stream_inputs}concat=n={n}:v=1:a=1[vout][aout]")
            filter_complex = ';'.join(filter_parts)
            cmd = ['ffmpeg', '-i', file_path,
                   '-filter_complex', filter_complex,
                   '-map', '[vout]', '-map', '[aout]',
                   temp_path, '-y']
        else:
            stream_inputs = ''.join(f'[v{i}]' for i in range(n))
            filter_parts.append(f"{stream_inputs}concat=n={n}:v=1:a=0[vout]")
            filter_complex = ';'.join(filter_parts)
            cmd = ['ffmpeg', '-i', file_path,
                   '-filter_complex', filter_complex,
                   '-map', '[vout]',
                   temp_path, '-y']

        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            if os.path.exists(temp_path):
                os.remove(temp_path)
            return flask.jsonify({'success': False, 'error': f'ffmpeg error: {result.stderr[-500:]}'}), 500

        os.replace(temp_path, file_path)
        return flask.jsonify({'success': True})

    except Exception as e:
        return flask.jsonify({'success': False, 'error': str(e)}), 500

@app.before_request
def refresh_session():
    flask.session.permanent = True
    flask.session.modified = True

def run():
    global args
    global url_for_prefix
    app.register_blueprint(bp)
    login_manager.init_app(app)
    login_manager.login_view = url_for_prefix + "login"
    app.run(host="0.0.0.0", port=args.port)

if __name__ == "__main__":
    run()
