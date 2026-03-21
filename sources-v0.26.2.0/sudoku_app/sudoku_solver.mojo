"""
Mojo Sudoku Solver — subprocess olarak çağrılır.

Kullanım:
  mojo sudoku_solver.mojo <81-char-puzzle-string>

Çıktı:
  {"solution":"<81-char>","elapsed_ns":<int>,"solved":<bool>}
"""

import sys
from time import perf_counter_ns


# ------------------------------------------------------------------ #
# Board helpers
# ------------------------------------------------------------------ #

fn make_board(flat: String) raises -> List[List[Int]]:
    """Parse 81-char string into 9x9 board."""
    var board = List[List[Int]]()
    for r in range(9):
        var row = List[Int]()
        for c in range(9):
            var idx = r * 9 + c
            # String'den karakter almak için codepoint_slices kullan
            var val = 0
            var i = 0
            for ch in flat.codepoint_slices():
                if i == idx:
                    val = Int(String(ch))
                    break
                i += 1
            row.append(val)
        board.append(row^)
    return board^


fn board_to_flat(board: List[List[Int]]) -> String:
    """Convert 9x9 board to 81-char string."""
    var result = String("")
    for r in range(9):
        for c in range(9):
            result += String(board[r][c])
    return result


fn copy_board(src: List[List[Int]]) -> List[List[Int]]:
    """Deep copy a 9x9 board."""
    var dst = List[List[Int]]()
    for r in range(9):
        var row = List[Int]()
        for c in range(9):
            row.append(src[r][c])
        dst.append(row^)
    return dst^


# ------------------------------------------------------------------ #
# Validator
# ------------------------------------------------------------------ #

fn is_valid(board: List[List[Int]], row: Int, col: Int, num: Int) -> Bool:
    """Check if num can be placed at board[row][col]."""
    for c in range(9):
        if board[row][c] == num:
            return False
    for r in range(9):
        if board[r][col] == num:
            return False
    var box_r = (row // 3) * 3
    var box_c = (col // 3) * 3
    for r in range(box_r, box_r + 3):
        for c in range(box_c, box_c + 3):
            if board[r][c] == num:
                return False
    return True


# ------------------------------------------------------------------ #
# find_empty — tuple dönemiyor, row/col ayrı out parametresi
# ------------------------------------------------------------------ #

fn find_empty_row(board: List[List[Int]]) -> Int:
    """Return row of first empty cell, or -1 if none."""
    for r in range(9):
        for c in range(9):
            if board[r][c] == 0:
                return r
    return -1


fn find_empty_col(board: List[List[Int]]) -> Int:
    """Return col of first empty cell, or -1 if none."""
    for r in range(9):
        for c in range(9):
            if board[r][c] == 0:
                return c
    return -1


# ------------------------------------------------------------------ #
# Solver — backtracking
# ------------------------------------------------------------------ #

fn solve(mut board: List[List[Int]]) -> Bool:
    """Solve in-place using backtracking. Returns True if solved."""
    var row = find_empty_row(board)
    var col = find_empty_col(board)

    if row == -1:
        return True   # no empty cell — solved

    for num in range(1, 10):
        if is_valid(board, row, col, num):
            board[row][col] = num
            if solve(board):
                return True
            board[row][col] = 0

    return False


# ------------------------------------------------------------------ #
# Main
# ------------------------------------------------------------------ #

fn main() raises:
    var argv = sys.argv()
    if len(argv) < 2:
        print('{"error":"Missing puzzle argument","solved":false}')
        return

    var flat = String(argv[1])
    if len(flat) != 81:
        print('{"error":"Puzzle must be 81 characters","solved":false}')
        return

    var board   = make_board(flat)
    var t0      = perf_counter_ns()
    var solved  = solve(board)
    var elapsed = perf_counter_ns() - t0

    var solution = board_to_flat(board) if solved else flat

    print(
        '{"solution":"' + solution + '"' +
        ',"elapsed_ns":' + String(elapsed) +
        ',"solved":' + ("true" if solved else "false") +
        '}'
    )
