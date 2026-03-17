"""
Author: Ahmet Aksoy
Date: 2026-03-16
Revision Date: 2026-03-16
Mojo version no: 0.26.1

Description:
    QR Code Creator & Reader web application built with Mojo + Flask.

    Mojo handles application startup and Flask configuration.
    QR generation, decoding and route handlers are in qrcode_helpers.py.
    HTML templates are in the qrcode_templates/ directory.

    Features:
      Creator:
        - Text / URL / vCard / WiFi QR code generation
        - Size selection: 200 / 300 / 400 / 600 px
        - Error correction: L / M / Q / H
        - Color themes: Black on White / Blue on White / White on Dark
        - Inline PNG preview
        - PNG download

      Reader:
        - Upload image (PNG, JPG, GIF, BMP, WebP) with drag & drop
        - Webcam live scanning via jsQR (browser-side, no server round-trip)
        - Auto-open URLs from decoded content
        - Copy to clipboard

    File structure:
      qrcode_app.mojo            <- this file
      qrcode_helpers.py          <- Flask routes + QR logic
      qrcode_templates/
        base.html
        create.html              <- QR code generator
        read.html                <- image upload + webcam reader

    Run:
      mojo qrcode_app.mojo
    Then open http://localhost:8117

Requirements:
    pip install flask qrcode[pil] pyzbar pillow
    
    Note: pyzbar also requires the zbar shared library:
      Ubuntu/Debian: sudo apt-get install libzbar0
      macOS:         brew install zbar
"""

from python import Python, PythonObject


fn main() raises:
    flask: PythonObject    = Python.import_module("flask")
    builtins: PythonObject = Python.import_module("builtins")

    var app: PythonObject = flask.Flask(
        builtins.str("__main__"),
        template_folder=builtins.str("qrcode_templates"),
        static_folder=builtins.str("static"),
        static_url_path=builtins.str("/static")
    )

    app.secret_key = builtins.str("mojo-qrcode-secret-key")

    qrcode_helpers: PythonObject = Python.import_module("qrcode_helpers")
    qrcode_helpers.setup_routes(app)

    print("=" * 50)
    print("  QR Code App starting on port 8117")
    print("  http://localhost:8117")
    print("  Press Ctrl+C to stop.")
    print("=" * 50)

    _ = app.run(host="0.0.0.0", port=8117, debug=False)
