{
  buildPythonPackage,
  setuptools,
  fetchPypi,
  pythonOlder,
  colorama,
  requests,
  lxml,
  pkg-src,
}:
buildPythonPackage rec {
  pname = "scrape";
  version = "0.0.1";
  pyproject = true;
  build-system = [ setuptools ];
  disabled = pythonOlder "3.6";
  propagatedBuildInputs = [
    colorama
    requests
    lxml
  ];
  src = pkg-src;
  meta = {
    description = "Scrape content off the internet, quickly.";
    longDescription = ''
      [Repository](https://github.com/goromal/scrape)

      This is a simple tool that assumes you want to download files from a straightforwardly-constructed HTML page. You'll need an XPath specification to help narrow down the scraping.

      **Resource files for testing scrape:**

      [sample_1280x720](https://github.com/goromal/anixdata/raw/master/data/media/scrape-tests/sample_1280x720.webm)

      [sample_1920x1080](https://github.com/goromal/anixdata/raw/master/data/media/scrape-tests/sample_1920x1080.webm)

      [sample_2560x1440](https://github.com/goromal/anixdata/raw/master/data/media/scrape-tests/sample_2560x1440.webm)

      [sample_3840x2160](https://github.com/goromal/anixdata/raw/master/data/media/scrape-tests/sample_3840x2160.webm)

      [sample_640x360](https://github.com/goromal/anixdata/raw/master/data/media/scrape-tests/sample_640x360.webm)

      [sample_960x400_ocean_with_audio](https://github.com/goromal/anixdata/raw/master/data/media/scrape-tests/sample_960x400_ocean_with_audio.webm)

      [sample_960x540](https://github.com/goromal/anixdata/raw/master/data/media/scrape-tests/sample_960x540.webm)

      [sample_640x360 (mp4)](https://github.com/goromal/anixdata/raw/master/data/media/scrape-tests/sample_640x360.mp4)
    '';
    autoGenUsageCmd = "--help";
  };
}
