"""
Expense Tracker Flask route handler helper.
Imported by expense_app.mojo via Python.import_module().
"""

import sqlite3
from flask import render_template, request, redirect, url_for, flash
from datetime import datetime, timedelta
import calendar

DB_PATH = "expense.db"


def get_conn():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def row_to_dict(row):
    return dict(zip(row.keys(), tuple(row)))


def get_stats(conn):
    total = conn.execute(
        "SELECT COALESCE(SUM(amount), 0) FROM expenses"
    ).fetchone()[0]
    count = conn.execute(
        "SELECT COUNT(*) FROM expenses"
    ).fetchone()[0]

    today      = datetime.now()
    month_str  = today.strftime('%Y-%m')
    week_start = (today - timedelta(days=today.weekday())).strftime('%Y-%m-%d')

    this_month = conn.execute(
        "SELECT COALESCE(SUM(amount), 0) FROM expenses WHERE date LIKE ?",
        (month_str + '%',)
    ).fetchone()[0]

    this_week = conn.execute(
        "SELECT COALESCE(SUM(amount), 0) FROM expenses WHERE date >= ?",
        (week_start,)
    ).fetchone()[0]

    return {
        'total'     : float(total),
        'count'     : count,
        'this_month': float(this_month),
        'this_week' : float(this_week)
    }


def get_cat_data(conn, year=None, month=None):
    if year and month:
        month_str = f"{year}-{month:02d}"
        rows = conn.execute(
            "SELECT category, SUM(amount) as total, COUNT(*) as cnt "
            "FROM expenses WHERE date LIKE ? "
            "GROUP BY category ORDER BY total DESC",
            (month_str + '%',)
        ).fetchall()
    else:
        rows = conn.execute(
            "SELECT category, SUM(amount) as total, COUNT(*) as cnt "
            "FROM expenses GROUP BY category ORDER BY total DESC"
        ).fetchall()
    return [row_to_dict(r) for r in rows]


def setup_routes(app):

    # ------------------------------------------------------------------ #
    # GET / — dashboard
    # ------------------------------------------------------------------ #
    @app.route('/')
    def index():
        conn     = get_conn()
        stats    = get_stats(conn)
        expenses = [row_to_dict(r) for r in conn.execute(
            "SELECT * FROM expenses ORDER BY date DESC, id DESC LIMIT 20"
        ).fetchall()]
        cat_data = get_cat_data(conn)
        conn.close()

        cat_labels = [r['category'] for r in cat_data]
        cat_values = [r['total']    for r in cat_data]

        return render_template('index.html',
            stats=stats,
            expenses=expenses,
            cat_data=cat_data,
            cat_labels=cat_labels,
            cat_values=cat_values
        )

    # ------------------------------------------------------------------ #
    # GET /add  — show form
    # POST /add — save expense
    # ------------------------------------------------------------------ #
    @app.route('/add', methods=['GET', 'POST'])
    def add_expense():
        if request.method == 'POST':
            description = request.form.get('description', '').strip()
            amount      = request.form.get('amount', '').strip()
            category    = request.form.get('category', 'Other')
            date        = request.form.get('date', '').strip()

            if not description or not amount or not date:
                flash('All fields are required.', 'error')
                return redirect(url_for('add_expense'))

            try:
                amount_f = float(amount)
                if amount_f <= 0:
                    raise ValueError
            except ValueError:
                flash('Amount must be a positive number.', 'error')
                return redirect(url_for('add_expense'))

            conn = get_conn()
            conn.execute(
                "INSERT INTO expenses (description, amount, category, date) "
                "VALUES (?, ?, ?, ?)",
                (description, amount_f, category, date)
            )
            conn.commit()
            conn.close()
            flash(f'Expense of ${amount_f:.2f} added!', 'success')
            return redirect(url_for('index'))

        today = datetime.now().strftime('%Y-%m-%d')
        return render_template('add.html', today=today)

    # ------------------------------------------------------------------ #
    # POST /delete/<id> — delete an expense
    # ------------------------------------------------------------------ #
    @app.route('/delete/<int:expense_id>', methods=['POST'])
    def delete_expense(expense_id):
        conn = get_conn()
        conn.execute("DELETE FROM expenses WHERE id=?", (expense_id,))
        conn.commit()
        conn.close()
        flash('Expense deleted.', 'success')
        # Redirect back to the referring page
        ref = request.referrer or url_for('index')
        return redirect(ref)

    # ------------------------------------------------------------------ #
    # GET /report  — monthly report
    # ------------------------------------------------------------------ #
    @app.route('/report')
    def report():
        today = datetime.now()
        year  = int(request.args.get('year',  today.year))
        month = int(request.args.get('month', today.month))

        # Previous / next month navigation
        if month == 1:
            prev_year, prev_month = year - 1, 12
        else:
            prev_year, prev_month = year, month - 1

        if month == 12:
            next_year, next_month = year + 1, 1
        else:
            next_year, next_month = year, month + 1

        month_str  = f"{year}-{month:02d}"
        month_name = calendar.month_name[month]
        days_in_month = calendar.monthrange(year, month)[1]

        conn = get_conn()

        # All expenses this month
        expenses = [row_to_dict(r) for r in conn.execute(
            "SELECT * FROM expenses WHERE date LIKE ? ORDER BY date ASC",
            (month_str + '%',)
        ).fetchall()]

        # Category breakdown
        cat_data = get_cat_data(conn, year, month)

        # Daily totals
        daily_map = {}
        for e in expenses:
            day = e['date'][8:10]  # DD
            daily_map[day] = daily_map.get(day, 0) + e['amount']

        daily_labels = [str(d) for d in range(1, days_in_month + 1)]
        daily_values = [round(daily_map.get(f"{d:02d}", 0), 2)
                        for d in range(1, days_in_month + 1)]

        monthly_total = sum(daily_values)
        entry_count   = len(expenses)
        daily_avg     = monthly_total / days_in_month if monthly_total else 0
        top_category  = cat_data[0]['category'] if cat_data else '—'

        conn.close()

        return render_template('report.html',
            year=year, month=month,
            month_name=month_name,
            prev_year=prev_year, prev_month=prev_month,
            next_year=next_year, next_month=next_month,
            expenses=expenses,
            cat_data=cat_data,
            daily_labels=daily_labels,
            daily_values=daily_values,
            monthly_total=monthly_total,
            entry_count=entry_count,
            daily_avg=daily_avg,
            top_category=top_category
        )
