"""
Sudoku App Flask route handler.
"""

import json
import subprocess
import os
import copy
from flask import render_template, request, jsonify
import sudoku_engine as engine


def run_mojo_solver(flat):
    """Run sudoku_solver.mojo via subprocess."""
    script = os.path.join(os.path.dirname(__file__), 'sudoku_solver.mojo')
    try:
        result = subprocess.run(
            ['mojo', script, flat],
            capture_output=True, text=True, timeout=60
        )
        for line in result.stdout.strip().splitlines():
            line = line.strip()
            if line.startswith('{'):
                return json.loads(line)
        raise ValueError(f'No JSON:\n{result.stdout}\n{result.stderr}')
    except Exception as e:
        return {'error': str(e), 'solved': False}


def setup_routes(app):

    # ---------------------------------------------------------------- #
    # GET / — main page
    # ---------------------------------------------------------------- #
    @app.route('/')
    def index():
        return render_template('index.html')

    # ---------------------------------------------------------------- #
    # POST /generate — generate a new puzzle
    # ---------------------------------------------------------------- #
    @app.route('/generate', methods=['POST'])
    def generate():
        data       = request.get_json(silent=True) or {}
        difficulty = data.get('difficulty', 'medium')
        seed       = data.get('seed')
        if seed:
            seed = int(seed)

        puzzle, solution = engine.generate(difficulty, seed)

        return jsonify({
            'puzzle'    : engine.board_to_list(puzzle),
            'solution'  : engine.board_to_list(solution),
            'flat'      : engine.board_to_flat(puzzle),
            'difficulty': difficulty,
        })

    # ---------------------------------------------------------------- #
    # POST /solve — solve with Python + Mojo, return steps + timing
    # ---------------------------------------------------------------- #
    @app.route('/solve', methods=['POST'])
    def solve():
        data    = request.get_json(silent=True) or {}
        flat    = data.get('flat', '')
        compare = data.get('compare', False)   # also run Mojo solver

        if len(flat) != 81:
            return jsonify({'error': 'Invalid puzzle'}), 400

        puzzle = engine.flat_to_board(flat)

        # Python solver with steps
        py_solution, steps, py_ns = engine.solve_with_steps(puzzle)

        response = {
            'py_solution': engine.board_to_list(py_solution) if py_solution else None,
            'py_ns'      : py_ns,
            'py_solved'  : py_solution is not None,
            'steps'      : steps,
            'step_count' : len(steps),
        }

        # Mojo solver (optional comparison)
        if compare:
            mojo_result = run_mojo_solver(flat)
            response['mojo_ns']     = mojo_result.get('elapsed_ns', 0)
            response['mojo_solved'] = mojo_result.get('solved', False)
            response['mojo_solution'] = list(mojo_result.get('solution', '')) \
                if mojo_result.get('solved') else None
            if response['mojo_ns'] and py_ns:
                response['speedup'] = round(py_ns / response['mojo_ns'], 2)

        return jsonify(response)

    # ---------------------------------------------------------------- #
    # POST /validate — check if a user-entered board is valid so far
    # ---------------------------------------------------------------- #
    @app.route('/validate', methods=['POST'])
    def validate():
        data  = request.get_json(silent=True) or {}
        cells = data.get('cells', [])   # flat list of 81 ints

        if len(cells) != 81:
            return jsonify({'valid': False, 'errors': []})

        board  = [[cells[r * 9 + c] for c in range(9)] for r in range(9)]
        errors = []

        for r in range(9):
            for c in range(9):
                num = board[r][c]
                if num == 0:
                    continue
                # Temporarily clear the cell and check
                board[r][c] = 0
                if not engine.is_valid(board, r, c, num):
                    errors.append(r * 9 + c)
                board[r][c] = num

        return jsonify({'valid': len(errors) == 0, 'errors': errors})
