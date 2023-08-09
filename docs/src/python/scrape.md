# python39.pkgs.scrape

Scrape content off the internet, quickly.

[Repository](https://github.com/goromal/scrape)

This is a simple tool that assumes you want to download files from a straightforwardly-constructed HTML page. You'll need an XPath specification to help narrow down the scraping.

```bash
usage: scrape [-h] [-o DIRNAME] {simple-link-scraper,simple-image-scraper} page

Scrape content off the internet, quickly.

positional arguments:
{simple-link-scraper,simple-image-scraper}
                        The type of content to be scraped.
page                  Webpage url.

optional arguments:
-h, --help            show this help message and exit
-o DIRNAME, --output DIRNAME
                        Output directory.
```

