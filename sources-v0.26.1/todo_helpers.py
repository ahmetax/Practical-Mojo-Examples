"""
To-Do List Flask route handler helper.
Imported by todo_app.mojo via Python.import_module().
"""

import sqlite3
from flask import render_template, request, redirect, url_for, flash
from datetime import datetime

DB_PATH = "todo.db"


def get_conn():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def row_to_dict(row):
    return dict(zip(row.keys(), tuple(row)))


def get_stats(conn):
    total   = conn.execute("SELECT COUNT(*) FROM tasks").fetchone()[0]
    done    = conn.execute("SELECT COUNT(*) FROM tasks WHERE done=1").fetchone()[0]
    pending = total - done
    high    = conn.execute(
        "SELECT COUNT(*) FROM tasks WHERE priority='high' AND done=0"
    ).fetchone()[0]
    return {
        'total'  : total,
        'done'   : done,
        'pending': pending,
        'high'   : high
    }


def setup_routes(app):

    # ------------------------------------------------------------------ #
    # GET / — task list with optional filter
    # ------------------------------------------------------------------ #
    @app.route('/')
    def index():
        f    = request.args.get('filter', 'all')
        conn = get_conn()

        if f == 'pending':
            rows = conn.execute(
                "SELECT * FROM tasks WHERE done=0 ORDER BY "
                "CASE priority WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END, id DESC"
            ).fetchall()
        elif f == 'done':
            rows = conn.execute(
                "SELECT * FROM tasks WHERE done=1 ORDER BY id DESC"
            ).fetchall()
        elif f == 'high':
            rows = conn.execute(
                "SELECT * FROM tasks WHERE priority='high' AND done=0 "
                "ORDER BY id DESC"
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT * FROM tasks ORDER BY done ASC, "
                "CASE priority WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END, id DESC"
            ).fetchall()

        tasks = []
        for row in rows:
            d = row_to_dict(row)
            # Shorten created_at to date only
            d['created_at'] = d['created_at'][:10]
            tasks.append(d)

        stats = get_stats(conn)
        conn.close()
        return render_template('index.html', tasks=tasks, stats=stats, filter=f)

    # ------------------------------------------------------------------ #
    # POST /add — add a new task
    # ------------------------------------------------------------------ #
    @app.route('/add', methods=['POST'])
    def add_task():
        title    = request.form.get('title', '').strip()
        priority = request.form.get('priority', 'medium')

        if not title:
            flash('Task title cannot be empty.', 'error')
            return redirect(url_for('index'))

        conn = get_conn()
        conn.execute(
            "INSERT INTO tasks (title, priority, done, created_at) VALUES (?, ?, 0, ?)",
            (title, priority, datetime.now().strftime('%Y-%m-%d %H:%M:%S'))
        )
        conn.commit()
        conn.close()
        flash('Task added!', 'success')
        return redirect(url_for('index'))

    # ------------------------------------------------------------------ #
    # POST /toggle/<id> — toggle done/undone
    # ------------------------------------------------------------------ #
    @app.route('/toggle/<int:task_id>', methods=['POST'])
    def toggle_task(task_id):
        conn = get_conn()
        conn.execute(
            "UPDATE tasks SET done = 1 - done WHERE id = ?", (task_id,)
        )
        conn.commit()
        conn.close()
        return redirect(url_for('index'))

    # ------------------------------------------------------------------ #
    # GET /edit/<id>  — show edit form
    # POST /edit/<id> — save changes
    # ------------------------------------------------------------------ #
    @app.route('/edit/<int:task_id>', methods=['GET', 'POST'])
    def edit_task(task_id):
        conn = get_conn()
        if request.method == 'POST':
            title    = request.form.get('title', '').strip()
            priority = request.form.get('priority', 'medium')
            if not title:
                flash('Task title cannot be empty.', 'error')
                return redirect(url_for('edit_task', task_id=task_id))
            conn.execute(
                "UPDATE tasks SET title=?, priority=? WHERE id=?",
                (title, priority, task_id)
            )
            conn.commit()
            conn.close()
            flash('Task updated!', 'success')
            return redirect(url_for('index'))

        row = conn.execute(
            "SELECT * FROM tasks WHERE id=?", (task_id,)
        ).fetchone()
        conn.close()
        if row is None:
            flash('Task not found.', 'error')
            return redirect(url_for('index'))
        return render_template('edit.html', task=row_to_dict(row))

    # ------------------------------------------------------------------ #
    # POST /delete/<id> — delete a task
    # ------------------------------------------------------------------ #
    @app.route('/delete/<int:task_id>', methods=['POST'])
    def delete_task(task_id):
        conn = get_conn()
        conn.execute("DELETE FROM tasks WHERE id=?", (task_id,))
        conn.commit()
        conn.close()
        flash('Task deleted.', 'success')
        return redirect(url_for('index'))

    # ------------------------------------------------------------------ #
    # POST /clear_done — delete all completed tasks
    # ------------------------------------------------------------------ #
    @app.route('/clear_done', methods=['POST'])
    def clear_done():
        conn = get_conn()
        conn.execute("DELETE FROM tasks WHERE done=1")
        conn.commit()
        conn.close()
        flash('Completed tasks cleared.', 'success')
        return redirect(url_for('index'))
