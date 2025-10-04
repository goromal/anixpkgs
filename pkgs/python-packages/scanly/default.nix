{ lib, python, buildPythonPackage, fetchPypi, requests, watchdog, urllib3, tqdm, plexapi, python-dotenv
, psutil, pkg-src }:
let
  tmdbv3api = buildPythonPackage rec {
    version = "1.9.0";
    pname = "tmdbv3api";
    src = fetchPypi {
      inherit pname version;
      sha256 = "UExdprmcRRb/FgoBV2ES0JfyCcBTT5Q8FcS1bL2Swzs=";
    };
    propagatedBuildInputs = [ requests urllib3 ];
    doCheck = false;
  };
in buildPythonPackage rec {
  version = "1.0.0";
  pname = "scanly";

  src = pkg-src;

  propagatedBuildInputs = [ requests watchdog tmdbv3api tqdm psutil plexapi python-dotenv ];

  doCheck = false;

  # ^^^^ TODO pkgshell . scanly --run "scanly"
  patchPhase = ''
  sed -i "/python_requires=/a \    entry_points={'console_scripts': ['scanly = src.main:main']}," setup.py
  sed -i 's/packages=.*/packages=find_packages(),/' setup.py
  sed -i 's/package_dir=.*//' setup.py
  sed -i 's/from utils/from src\.utils/' src/main.py
  sed -i "s|log_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'logs')|log_dir = 'logs'|g" src/main.py
  sed -i "s|SCAN_HISTORY_FILE = os.path.join(os.path.dirname(__file__), 'scan_history.txt')|SCAN_HISTORY_FILE = 'scan_history.txt'|g" src/main.py
  sed -i "s|SCAN_HISTORY_DB = os.path.join(os.path.dirname(__file__), 'scan_history.db')|SCAN_HISTORY_DB = 'scan_history.db'|g" src/main.py
  sed -i "s|SCAN_HISTORY_FILE = os.path.join(os.path.dirname(__file__), 'scan_history.txt')|SCAN_HISTORY_FILE = 'scan_history.txt'|g" src/utils/scan_history_utils.py
  sed -i "s|SCAN_HISTORY_DB = os.path.join(os.path.dirname(__file__), 'scan_history.db')|SCAN_HISTORY_DB = 'scan_history.db'|g" src/utils/scan_history_utils.py
'';

  meta = with lib; {
    homepage = "https://github.com/amcgready/Scanly";
    description = "Personal home media management tool.";
    longDescription = "[Homepage](https://github.com/amcgready/Scanly)";
  };
}
