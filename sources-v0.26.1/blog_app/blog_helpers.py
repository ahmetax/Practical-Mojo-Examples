"""
Blog App Flask route handler helper.
Imported by blog_app.mojo via Python.import_module().

Authentication:
  - Passwords hashed with bcrypt
  - Login state stored in Flask session
  - login_required decorator protects private routes
"""

import sqlite3
import re
from functools import wraps
from datetime import datetime

import bcrypt
from flask import (
    render_template, request, redirect, url_for,
    flash, session
)

DB_PATH = "blog.db"


# ------------------------------------------------------------------ #
# DB helpers
# ------------------------------------------------------------------ #
def get_conn():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def row_to_dict(row):
    if row is None:
        return None
    return dict(zip(row.keys(), tuple(row)))


# ------------------------------------------------------------------ #
# Auth helpers
# ------------------------------------------------------------------ #
def hash_password(plain):
    return bcrypt.hashpw(plain.encode(), bcrypt.gensalt()).decode()


def check_password(plain, hashed):
    return bcrypt.checkpw(plain.encode(), hashed.encode())


def login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if not session.get('user_id'):
            flash('Please log in to access this page.', 'error')
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated


# ------------------------------------------------------------------ #
# Route setup
# ------------------------------------------------------------------ #
def setup_routes(app):

    # ---- Public: home -------------------------------------------- #
    @app.route('/')
    def index():
        conn = get_conn()
        rows = conn.execute(
            "SELECT p.*, u.username FROM posts p "
            "JOIN users u ON p.user_id = u.id "
            "ORDER BY p.created_at DESC"
        ).fetchall()
        conn.close()
        posts = [row_to_dict(r) for r in rows]
        return render_template('index.html', posts=posts)

    # ---- Public: single post ------------------------------------- #
    @app.route('/post/<int:post_id>')
    def view_post(post_id):
        conn = get_conn()
        row  = conn.execute(
            "SELECT p.*, u.username FROM posts p "
            "JOIN users u ON p.user_id = u.id WHERE p.id = ?",
            (post_id,)
        ).fetchone()
        conn.close()
        if row is None:
            flash('Post not found.', 'error')
            return redirect(url_for('index'))
        return render_template('post.html', post=row_to_dict(row))

    # ---- Auth: register ------------------------------------------ #
    @app.route('/register', methods=['GET', 'POST'])
    def register():
        if session.get('user_id'):
            return redirect(url_for('index'))

        if request.method == 'POST':
            username  = request.form.get('username', '').strip()
            email     = request.form.get('email', '').strip().lower()
            password  = request.form.get('password', '')
            password2 = request.form.get('password2', '')

            # Validation
            if not re.match(r'^[a-zA-Z0-9_]{3,32}$', username):
                flash('Username must be 3–32 characters (letters, numbers, underscore).', 'error')
                return render_template('register.html',
                                       username=username, email=email)

            if not re.match(r'^[^@\s]+@[^@\s]+\.[^@\s]+$', email):
                flash('Please enter a valid email address.', 'error')
                return render_template('register.html',
                                       username=username, email=email)

            if len(password) < 6:
                flash('Password must be at least 6 characters.', 'error')
                return render_template('register.html',
                                       username=username, email=email)

            if password != password2:
                flash('Passwords do not match.', 'error')
                return render_template('register.html',
                                       username=username, email=email)

            conn = get_conn()
            # Check duplicates
            if conn.execute(
                "SELECT id FROM users WHERE username = ?", (username,)
            ).fetchone():
                conn.close()
                flash('Username already taken.', 'error')
                return render_template('register.html',
                                       username=username, email=email)

            if conn.execute(
                "SELECT id FROM users WHERE email = ?", (email,)
            ).fetchone():
                conn.close()
                flash('Email already registered.', 'error')
                return render_template('register.html',
                                       username=username, email=email)

            hashed = hash_password(password)
            now    = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            conn.execute(
                "INSERT INTO users (username, email, password, created_at) "
                "VALUES (?, ?, ?, ?)",
                (username, email, hashed, now)
            )
            conn.commit()

            # Auto-login after register
            user = row_to_dict(conn.execute(
                "SELECT * FROM users WHERE username = ?", (username,)
            ).fetchone())
            conn.close()

            session['user_id']  = user['id']
            session['username'] = user['username']
            flash(f'Welcome, {username}! Your account has been created.', 'success')
            return redirect(url_for('dashboard'))

        return render_template('register.html')

    # ---- Auth: login --------------------------------------------- #
    @app.route('/login', methods=['GET', 'POST'])
    def login():
        if session.get('user_id'):
            return redirect(url_for('index'))

        if request.method == 'POST':
            username = request.form.get('username', '').strip()
            password = request.form.get('password', '')

            conn = get_conn()
            row  = conn.execute(
                "SELECT * FROM users WHERE username = ?", (username,)
            ).fetchone()
            conn.close()

            if row is None or not check_password(password, row['password']):
                flash('Invalid username or password.', 'error')
                return render_template('login.html', username=username)

            session['user_id']  = row['id']
            session['username'] = row['username']
            flash(f'Welcome back, {row["username"]}!', 'success')
            next_url = request.args.get('next') or url_for('dashboard')
            return redirect(next_url)

        return render_template('login.html')

    # ---- Auth: logout -------------------------------------------- #
    @app.route('/logout')
    def logout():
        session.clear()
        flash('You have been logged out.', 'info')
        return redirect(url_for('index'))

    # ---- Protected: dashboard ------------------------------------ #
    @app.route('/dashboard')
    @login_required
    def dashboard():
        conn = get_conn()
        rows = conn.execute(
            "SELECT * FROM posts WHERE user_id = ? ORDER BY created_at DESC",
            (session['user_id'],)
        ).fetchall()
        conn.close()
        posts = [row_to_dict(r) for r in rows]
        return render_template('dashboard.html', posts=posts)

    # ---- Protected: new post ------------------------------------- #
    @app.route('/post/new', methods=['GET', 'POST'])
    @login_required
    def new_post():
        if request.method == 'POST':
            title = request.form.get('title', '').strip()
            body  = request.form.get('body', '').strip()

            if not title or not body:
                flash('Title and content are required.', 'error')
                return render_template('post_form.html', post=None)

            now  = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            conn = get_conn()
            cur  = conn.execute(
                "INSERT INTO posts (user_id, title, body, created_at, updated_at) "
                "VALUES (?, ?, ?, ?, ?)",
                (session['user_id'], title, body, now, now)
            )
            conn.commit()
            post_id = cur.lastrowid
            conn.close()
            flash('Post published!', 'success')
            return redirect(url_for('view_post', post_id=post_id))

        return render_template('post_form.html', post=None)

    # ---- Protected: edit post ------------------------------------ #
    @app.route('/post/edit/<int:post_id>', methods=['GET', 'POST'])
    @login_required
    def edit_post(post_id):
        conn = get_conn()
        row  = conn.execute(
            "SELECT * FROM posts WHERE id = ?", (post_id,)
        ).fetchone()

        if row is None:
            conn.close()
            flash('Post not found.', 'error')
            return redirect(url_for('dashboard'))

        post = row_to_dict(row)
        if post['user_id'] != session['user_id']:
            conn.close()
            flash('You can only edit your own posts.', 'error')
            return redirect(url_for('dashboard'))

        if request.method == 'POST':
            title = request.form.get('title', '').strip()
            body  = request.form.get('body', '').strip()

            if not title or not body:
                flash('Title and content are required.', 'error')
                conn.close()
                return render_template('post_form.html', post=post)

            now = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            conn.execute(
                "UPDATE posts SET title=?, body=?, updated_at=? WHERE id=?",
                (title, body, now, post_id)
            )
            conn.commit()
            conn.close()
            flash('Post updated!', 'success')
            return redirect(url_for('view_post', post_id=post_id))

        conn.close()
        return render_template('post_form.html', post=post)

    # ---- Protected: delete post ---------------------------------- #
    @app.route('/post/delete/<int:post_id>', methods=['POST'])
    @login_required
    def delete_post(post_id):
        conn = get_conn()
        row  = conn.execute(
            "SELECT user_id FROM posts WHERE id = ?", (post_id,)
        ).fetchone()

        if row is None:
            conn.close()
            flash('Post not found.', 'error')
            return redirect(url_for('dashboard'))

        if row['user_id'] != session['user_id']:
            conn.close()
            flash('You can only delete your own posts.', 'error')
            return redirect(url_for('dashboard'))

        conn.execute("DELETE FROM posts WHERE id = ?", (post_id,))
        conn.commit()
        conn.close()
        flash('Post deleted.', 'success')
        return redirect(url_for('dashboard'))

    # ---- Protected: profile -------------------------------------- #
    @app.route('/profile')
    @login_required
    def profile():
        conn = get_conn()
        user = row_to_dict(conn.execute(
            "SELECT * FROM users WHERE id = ?", (session['user_id'],)
        ).fetchone())
        post_count = conn.execute(
            "SELECT COUNT(*) FROM posts WHERE user_id = ?",
            (session['user_id'],)
        ).fetchone()[0]
        conn.close()
        return render_template('profile.html', user=user, post_count=post_count)

    # ---- Protected: change password ------------------------------ #
    @app.route('/profile/password', methods=['POST'])
    @login_required
    def change_password():
        current  = request.form.get('current_password', '')
        new_pw   = request.form.get('new_password', '')
        new_pw2  = request.form.get('new_password2', '')

        conn = get_conn()
        user = row_to_dict(conn.execute(
            "SELECT * FROM users WHERE id = ?", (session['user_id'],)
        ).fetchone())

        if not check_password(current, user['password']):
            conn.close()
            flash('Current password is incorrect.', 'error')
            return redirect(url_for('profile'))

        if len(new_pw) < 6:
            conn.close()
            flash('New password must be at least 6 characters.', 'error')
            return redirect(url_for('profile'))

        if new_pw != new_pw2:
            conn.close()
            flash('New passwords do not match.', 'error')
            return redirect(url_for('profile'))

        hashed = hash_password(new_pw)
        conn.execute(
            "UPDATE users SET password = ? WHERE id = ?",
            (hashed, session['user_id'])
        )
        conn.commit()
        conn.close()
        flash('Password updated successfully!', 'success')
        return redirect(url_for('profile'))

    # ---- Protected: delete account ------------------------------- #
    @app.route('/profile/delete', methods=['POST'])
    @login_required
    def delete_account():
        conn = get_conn()
        conn.execute("DELETE FROM posts WHERE user_id = ?", (session['user_id'],))
        conn.execute("DELETE FROM users WHERE id = ?",      (session['user_id'],))
        conn.commit()
        conn.close()
        session.clear()
        flash('Your account has been deleted.', 'info')
        return redirect(url_for('index'))
