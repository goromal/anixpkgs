{ buildPythonPackage, fetchPypi, pythonOlder, colorama, requests, lxml, pkg-src
}:
buildPythonPackage rec {
  pname = "scrape";
  version = "0.0.1";
  disabled = pythonOlder "3.6";
  propagatedBuildInputs = [ colorama requests lxml ];
  src = pkg-src;
  meta = {
    description = "Scrape content off the internet, quickly.";
    longDescription = ''
      [Repository](https://github.com/goromal/scrape)

      This is a simple tool that assumes you want to download files from a straightforwardly-constructed HTML page. You'll need an XPath specification to help narrow down the scraping.

      ```bash
      usage: scrape [-h] [--xpath XPATH] [--ext EXT] [-o DIRNAME] {simple-link-scraper,simple-image-scraper} page

      Scrape content off the internet, quickly.

      positional arguments:
        {simple-link-scraper,simple-image-scraper}
                              The type of content to be scraped.
        page                  Webpage url.

      optional arguments:
        -h, --help            show this help message and exit
        --xpath XPATH         Optionally specify the XPath
        --ext EXT             Optionally specify the file extension
        -o DIRNAME, --output DIRNAME
                              Output directory.
      ```
    '';
  };
}
