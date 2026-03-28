"""
Author: Ahmet Aksoy
Date: 2026-03-12
Mojo version: 0.26.2 | Python 3.12 | Ubuntu

Description:
    Weather App built with Mojo + Flask + OpenWeatherMap API.

    Mojo handles application startup and Flask configuration.
    API calls and route handlers are in weather_helpers.py.
    HTML templates are in the weather_templates/ directory.

    Features:
      - Search any city worldwide
      - Current weather: temperature, feels like, humidity,
        wind speed, pressure, visibility, sunrise/sunset
      - 5-day forecast with daily min/max temperatures
      - Weather condition emoji icons
      - Recent searches (stored in session)

    File structure:
      weather_app.mojo           <- this file
      weather_helpers.py         <- Flask routes + API calls
      weather_templates/
        base.html
        index.html               <- search + current + forecast

    Run:
      mojo weather_app.mojo
    Then open http://localhost:8117

Requirements:
    pip install flask requests
"""

from std.python import Python, PythonObject


fn main() raises:
    flask: PythonObject    = Python.import_module("flask")
    builtins: PythonObject = Python.import_module("builtins")

    var app: PythonObject = flask.Flask(
        builtins.str("__main__"),
        template_folder=builtins.str("weather_templates")
    )

    app.secret_key = builtins.str("mojo-weather-secret-key")

    weather_helpers: PythonObject = Python.import_module("weather_helpers")
    weather_helpers.setup_routes(app)

    print("=" * 48)
    print("  Weather App starting on port 8117")
    print("  http://localhost:8117")
    print("  Press Ctrl+C to stop.")
    print("=" * 48)

    _ = app.run(host="0.0.0.0", port=8117, debug=False)
