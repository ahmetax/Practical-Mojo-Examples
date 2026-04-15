"""
Flask route handler helper.
Imported by flask_hello.mojo via Python.import_module().
"""

from flask import jsonify


def setup_routes(app):
    @app.route('/')
    def index():
        return 'Hello from Mojo + Flask!'

    @app.route('/ping')
    def ping():
        return jsonify({'status': 'ok', 'message': 'Mojo + Flask is running!'})
