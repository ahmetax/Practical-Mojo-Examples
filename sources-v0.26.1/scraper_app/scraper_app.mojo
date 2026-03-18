"""
Author: Ahmet Aksoy
Date: 2026-03-17
Revision Date: 2026-03-17
Mojo version no: 0.26.1
AI: Claude Sonnet 4.6

Description:
    General-purpose Web Scraper built with Mojo + Flask + BeautifulSoup.

    Mojo handles application startup and Flask configuration.
    Scraping logic and route handlers are in scraper_helpers.py.
    HTML templates are in the scraper_templates/ directory.

    Features:
      - Scrape any public URL
      - Selectable data types:
          Meta tags (title, description, og:*, charset...)
          Headings (h1-h6 with tag labels)
          Links (href + anchor text, absolute URLs)
          Images (src + alt, absolute URLs)
          Page text (cleaned, script/style removed)
          Tables (headers + rows)
      - Advanced options:
          Timeout, max links, max images, User-Agent selection
      - Results displayed inline with stats
      - Download results as JSON
      - Scrape history (in-memory, current session)
      - History view with re-open and download

    File structure:
      scraper_app.mojo           <- this file
      scraper_helpers.py         <- Flask routes + scraping logic
      scraper_templates/
        base.html
        index.html               <- scrape form
        result.html              <- scrape results
        history.html             <- past scrapes

    Run:
      mojo scraper_app.mojo
    Then open http://localhost:8117

Requirements:
    pip install flask requests beautifulsoup4
"""

from python import Python, PythonObject


fn main() raises:
    flask: PythonObject    = Python.import_module("flask")
    builtins: PythonObject = Python.import_module("builtins")

    var app: PythonObject = flask.Flask(
        builtins.str("__main__"),
        template_folder=builtins.str("scraper_templates")
    )

    app.secret_key = builtins.str("mojo-scraper-secret-key")

    scraper_helpers: PythonObject = Python.import_module("scraper_helpers")
    scraper_helpers.setup_routes(app)

    print("=" * 50)
    print("  Web Scraper starting on port 8117")
    print("  http://localhost:8117")
    print("  Press Ctrl+C to stop.")
    print("=" * 50)

    _ = app.run(host="0.0.0.0", port=8117, debug=False)
