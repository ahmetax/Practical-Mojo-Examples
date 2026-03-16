"""
Author: Ahmet Aksoy
Date: 2026-03-15
Revision Date: 2026-03-15
Mojo version no: 0.26.1

Description:
    Real-time Chat Application built with Mojo + Flask + Flask-SocketIO.

    Mojo handles application startup and Flask configuration.
    All SocketIO event handlers are in chat_helpers.py.
    The single-page UI is in chat_templates/index.html.

    Features:
      - Username selection on entry (unique across all rooms)
      - Three chat rooms: #general, #tech, #random
      - Switch rooms without page reload
      - Message history per room (last 50 messages, in memory)
      - Real-time join/leave/switch notifications
      - Live online user list per room
      - Live room user counts in sidebar
      - Auto-scroll to latest message
      - XSS-safe message rendering

    Architecture:
      Mojo (startup)
        └── Flask + Flask-SocketIO
              └── chat_helpers.py (event handlers)
                    └── In-memory state (room_history, room_users, sid maps)

    WebSocket events:
      Client → Server:  join, switch_room, message
      Server → Client:  joined, username_taken, message, system, room_users

    File structure:
      chat_app.mojo              <- this file
      chat_helpers.py            <- SocketIO event handlers
      chat_templates/
        index.html               <- single-page chat UI

    Run:
      mojo chat_app.mojo
    Then open http://localhost:8117 in two or more browser tabs.

Requirements:
    pip install flask flask-socketio
"""

from python import Python, PythonObject


fn main() raises:
    flask: PythonObject       = Python.import_module("flask")
    flask_socketio: PythonObject = Python.import_module("flask_socketio")
    builtins: PythonObject    = Python.import_module("builtins")

    var app: PythonObject = flask.Flask(
        builtins.str("__main__"),
        template_folder=builtins.str("chat_templates")
    )

    app.secret_key = builtins.str("mojo-chat-secret-key")

    # async_mode='threading' works without eventlet/gevent
    var socketio: PythonObject = flask_socketio.SocketIO(
        app,
        async_mode=builtins.str("threading"),
        cors_allowed_origins=builtins.str("*")
    )

    # Register SocketIO event handlers
    chat_helpers: PythonObject = Python.import_module("chat_helpers")
    chat_helpers.setup_events(socketio)

    # Serve the single-page UI
    var render = Python.evaluate(
        "lambda app, tmpl: app.route('/')(lambda: __import__('flask').render_template(tmpl))"
    )
    _ = render(app, builtins.str("index.html"))

    print("=" * 50)
    print("  MojoChat starting on port 8117")
    print("  http://localhost:8117")
    print("  Open in multiple browser tabs to test chat!")
    print("  Press Ctrl+C to stop.")
    print("=" * 50)

    _ = socketio.run(
        app,
        host="0.0.0.0",
        port=8117,
        debug=False,
        allow_unsafe_werkzeug=True
    )
