"""
Sudoku Engine — Creator and Python Solver.
"""

import random
import copy
import time


# ------------------------------------------------------------------ #
# Validation helpers
# ------------------------------------------------------------------ #

def is_valid(board, row, col, num):
    """Check if num can be placed at board[row][col]."""
    # Row check
    if num in board[row]:
        return False
    # Column check
    if num in [board[r][col] for r in range(9)]:
        return False
    # 3x3 box check
    box_r = (row // 3) * 3
    box_c = (col // 3) * 3
    for r in range(box_r, box_r + 3):
        for c in range(box_c, box_c + 3):
            if board[r][c] == num:
                return False
    return True


def find_empty(board):
    """Find next empty cell (value 0). Returns (row, col) or None."""
    for r in range(9):
        for c in range(9):
            if board[r][c] == 0:
                return (r, c)
    return None


# ------------------------------------------------------------------ #
# Solver — backtracking
# ------------------------------------------------------------------ #

def solve(board):
    """Solve in-place using backtracking. Returns True if solved."""
    pos = find_empty(board)
    if pos is None:
        return True   # solved

    row, col = pos
    nums = list(range(1, 10))
    random.shuffle(nums)   # shuffle for variety when generating

    for num in nums:
        if is_valid(board, row, col, num):
            board[row][col] = num
            if solve(board):
                return True
            board[row][col] = 0

    return False


def solve_with_steps(board):
    """
    Solve using backtracking, recording every step.
    Returns (solved_board, steps) where steps is a list of:
      {'row': r, 'col': c, 'num': n, 'action': 'place'|'backtrack'}
    """
    steps = []

    def _solve(b):
        pos = find_empty(b)
        if pos is None:
            return True

        row, col = pos
        for num in range(1, 10):
            if is_valid(b, row, col, num):
                b[row][col] = num
                steps.append({'row': row, 'col': col,
                               'num': num, 'action': 'place'})
                if _solve(b):
                    return True
                b[row][col] = 0
                steps.append({'row': row, 'col': col,
                               'num': 0, 'action': 'backtrack'})
        return False

    board_copy = copy.deepcopy(board)
    t0 = time.perf_counter_ns()
    solved = _solve(board_copy)
    elapsed_ns = time.perf_counter_ns() - t0

    return board_copy if solved else None, steps, elapsed_ns


def solve_timed(board):
    """Solve without recording steps, just measure time."""
    board_copy = copy.deepcopy(board)
    t0 = time.perf_counter_ns()
    solved = solve(board_copy)
    elapsed_ns = time.perf_counter_ns() - t0
    return board_copy if solved else None, elapsed_ns


# ------------------------------------------------------------------ #
# Generator
# ------------------------------------------------------------------ #

CLUES = {
    'easy'  : 36,   # 36 givens → 45 empty
    'medium': 27,   # 27 givens → 54 empty
    'hard'  : 22,   # 22 givens → 59 empty
}


def generate(difficulty='medium', seed=None):
    """
    Generate a valid Sudoku puzzle.
    Returns (puzzle, solution) where puzzle has 0s for empty cells.
    """
    if seed is not None:
        random.seed(seed)

    # Start with empty board and solve it (shuffled → random solution)
    board = [[0] * 9 for _ in range(9)]
    solve(board)
    solution = copy.deepcopy(board)

    # Remove cells to create the puzzle
    clues    = CLUES.get(difficulty, 27)
    to_remove = 81 - clues

    cells = [(r, c) for r in range(9) for c in range(9)]
    random.shuffle(cells)

    removed = 0
    for r, c in cells:
        if removed >= to_remove:
            break
        backup = board[r][c]
        board[r][c] = 0

        # Verify puzzle still has a unique solution
        test = copy.deepcopy(board)
        if solve(test):
            removed += 1
        else:
            board[r][c] = backup   # restore if unsolvable

    return board, solution


# ------------------------------------------------------------------ #
# Board helpers
# ------------------------------------------------------------------ #

def board_to_flat(board):
    """Convert 9x9 list to flat 81-char string (0 = empty)."""
    return ''.join(str(board[r][c]) for r in range(9) for c in range(9))


def flat_to_board(flat):
    """Convert flat 81-char string to 9x9 list."""
    flat = flat.strip()
    return [[int(flat[r * 9 + c]) for c in range(9)] for r in range(9)]


def board_to_list(board):
    """Convert 9x9 list to flat Python list for JSON serialization."""
    return [board[r][c] for r in range(9) for c in range(9)]
