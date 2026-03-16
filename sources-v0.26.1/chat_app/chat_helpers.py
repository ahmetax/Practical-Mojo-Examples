"""
MojoChat SocketIO event handler helper.
Imported by chat_app.mojo via Python.import_module().

Events (client -> server):
  join         { username, room }
  switch_room  { prev_room, new_room }
  message      { room, text }

Events (server -> client):
  joined       { history }
  username_taken
  message      { username, text, time }
  system       { text }
  room_users   { users, counts }
"""

from datetime import datetime
from collections import defaultdict
from flask import request
from flask_socketio import emit, join_room, leave_room

ROOMS       = ['general', 'tech', 'random']
MAX_HISTORY = 50

# { room: [{ username, text, time }, ...] }
room_history = defaultdict(list)

# { room: set(username) }
room_users = defaultdict(set)

# { sid: username }
sid_to_user = {}

# { sid: current_room }
sid_to_room = {}


def now_str():
    return datetime.now().strftime('%H:%M')


def get_room_counts():
    return {room: len(room_users[room]) for room in ROOMS}


def broadcast_users(socketio, room):
    """Send updated user list and room counts to everyone in the room."""
    socketio.emit('room_users', {
        'users' : sorted(room_users[room]),
        'counts': get_room_counts()
    }, to=room)


def setup_events(socketio):

    # ------------------------------------------------------------------ #
    # connect
    # ------------------------------------------------------------------ #
    @socketio.on('connect')
    def on_connect():
        pass   # username collected via 'join' event

    # ------------------------------------------------------------------ #
    # join — first entry into a room
    # ------------------------------------------------------------------ #
    @socketio.on('join')
    def on_join(data):
        username = str(data.get('username', '')).strip()
        room     = str(data.get('room', 'general'))
        sid      = request.sid

        if room not in ROOMS:
            room = 'general'

        # Reject duplicate usernames across all rooms
        for r in ROOMS:
            if username in room_users[r]:
                emit('username_taken')
                return

        # Track state
        sid_to_user[sid] = username
        sid_to_room[sid] = room

        join_room(room)
        room_users[room].add(username)

        # Send room history to the new user
        emit('joined', {'history': list(room_history[room])})

        # Notify others in the room
        emit('system', {'text': f'{username} joined #{room}'},
             to=room, include_self=False)

        broadcast_users(socketio, room)

    # ------------------------------------------------------------------ #
    # switch_room — user changes to a different room
    # ------------------------------------------------------------------ #
    @socketio.on('switch_room')
    def on_switch_room(data):
        sid       = request.sid
        username  = sid_to_user.get(sid)
        prev_room = str(data.get('prev_room', 'general'))
        new_room  = str(data.get('new_room',  'general'))

        if not username:
            return
        if new_room not in ROOMS:
            new_room = 'general'
        if new_room == prev_room:
            return

        # Leave old room
        leave_room(prev_room)
        room_users[prev_room].discard(username)
        emit('system', {'text': f'{username} left #{prev_room}'},
             to=prev_room, include_self=False)
        broadcast_users(socketio, prev_room)

        # Join new room
        join_room(new_room)
        room_users[new_room].add(username)
        sid_to_room[sid] = new_room

        # Send history of new room to the user
        emit('joined', {'history': list(room_history[new_room])})

        # Notify others in new room
        emit('system', {'text': f'{username} joined #{new_room}'},
             to=new_room, include_self=False)

        broadcast_users(socketio, new_room)

    # ------------------------------------------------------------------ #
    # message — user sends a chat message
    # ------------------------------------------------------------------ #
    @socketio.on('message')
    def on_message(data):
        sid      = request.sid
        username = sid_to_user.get(sid, 'Unknown')
        room     = str(data.get('room', 'general'))
        text     = str(data.get('text', '')).strip()

        if not text or room not in ROOMS:
            return

        msg = {
            'username': username,
            'text'    : text,
            'time'    : now_str()
        }

        # Append to history, trim if needed
        room_history[room].append(msg)
        if len(room_history[room]) > MAX_HISTORY:
            room_history[room] = room_history[room][-MAX_HISTORY:]

        # Broadcast to everyone in the room including sender
        socketio.emit('message', msg, to=room)

    # ------------------------------------------------------------------ #
    # disconnect — clean up when user closes tab/browser
    # ------------------------------------------------------------------ #
    @socketio.on('disconnect')
    def on_disconnect():
        sid      = request.sid
        username = sid_to_user.pop(sid, None)
        room     = sid_to_room.pop(sid, None)

        if not username or not room:
            return

        room_users[room].discard(username)

        emit('system', {'text': f'{username} left the chat'},
             to=room, include_self=False)

        broadcast_users(socketio, room)
