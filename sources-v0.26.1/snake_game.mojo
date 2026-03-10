"""
Author: Ahmet Aksoy
Date: 2026-03-09
Revision Date: 2026-03-09
Mojo version no: 0.26.1
AI: Claude Sonnet 4.6

Description:
    Classic Snake game implemented in Mojo using Python's tkinter library.

    Game state is stored in a Python dict (PythonObject) to work around
    Mojo 0.26.1's restriction that functions may have at most one 'out'
    argument. All state reads and writes go through the dict.

    The game logic (movement, collision, food placement, scoring) is
    implemented in Mojo functions. The graphical interface (window,
    canvas, keyboard input) is handled by tkinter via Python interop.

    Controls:
      Arrow keys — change direction
      R          — restart after game over
      Q          — quit
      A          — auto mode on/off

    Rules:
      - Snake grows by 1 segment each time it eats food.
      - Game ends if the snake hits a wall or its own body.
      - Score increases by 10 for each food eaten.

Requirements:
    tkinter is included in Python's standard library.
    No additional packages needed.
"""

from python import Python, PythonObject

comptime DIR_UP    = 0
comptime DIR_DOWN  = 1
comptime DIR_LEFT  = 2
comptime DIR_RIGHT = 3


fn make_state(grid_w: Int, grid_h: Int) raises -> PythonObject:
    """
    Create and return the initial game state as a Python dict.
    Using a Python dict avoids Mojo's 'multiple out arguments' restriction —
    all mutable state is stored in one PythonObject passed by reference.

    Keys:
      body_x, body_y : Python lists of Int — snake segments, head at index 0
      dir            : current direction (DIR_* constant)
      dx, dy         : movement delta per step
      score          : current score
      alive          : True while game is running
      food_x, food_y : current food position
      grid_w, grid_h : grid dimensions
    """
    random: PythonObject = Python.import_module("random")

    builtins: PythonObject = Python.import_module("builtins")

    var cx = grid_w // 2
    var cy = grid_h // 2

    var bx: PythonObject = builtins.list()
    bx.append(cx)
    bx.append(cx - 1)
    bx.append(cx - 2)

    var by: PythonObject = builtins.list()
    by.append(cy)
    by.append(cy)
    by.append(cy)

    var s = Python.dict()
    s["body_x"]  = bx
    s["body_y"]  = by
    s["dir"]     = DIR_RIGHT
    s["dx"]      = 1
    s["dy"]      = 0
    s["score"]   = 0
    s["alive"]   = True
    s["grid_w"]  = grid_w
    s["grid_h"]  = grid_h
    s["food_x"]  = 0
    s["food_y"]  = 0
    place_food(s)
    return s


fn place_food(s: PythonObject) raises:
    """Place food at a random unoccupied cell."""
    random: PythonObject = Python.import_module("random")

    var grid_w = Int(Float64(String(s["grid_w"])))
    var grid_h = Int(Float64(String(s["grid_h"])))
    var n      = Int(Float64(String(len(s["body_x"]))))

    while True:
        var fx = Int(Float64(String(random.randint(0, grid_w - 1))))
        var fy = Int(Float64(String(random.randint(0, grid_h - 1))))
        var occupied = False
        for i in range(n):
            var bx = Int(Float64(String(s["body_x"][i])))
            var by = Int(Float64(String(s["body_y"][i])))
            if bx == fx and by == fy:
                occupied = True
                break
        if not occupied:
            s["food_x"] = fx
            s["food_y"] = fy
            break


fn set_direction(s: PythonObject, new_dir: Int) raises:
    """Update direction, ignoring 180-degree reversals."""
    var cur = Int(Float64(String(s["dir"])))

    if new_dir == DIR_UP and cur != DIR_DOWN:
        s["dir"] = DIR_UP;    s["dx"] = 0;  s["dy"] = -1
    elif new_dir == DIR_DOWN and cur != DIR_UP:
        s["dir"] = DIR_DOWN;  s["dx"] = 0;  s["dy"] = 1
    elif new_dir == DIR_LEFT and cur != DIR_RIGHT:
        s["dir"] = DIR_LEFT;  s["dx"] = -1; s["dy"] = 0
    elif new_dir == DIR_RIGHT and cur != DIR_LEFT:
        s["dir"] = DIR_RIGHT; s["dx"] = 1;  s["dy"] = 0


fn move_snake(s: PythonObject) raises:
    """
    Advance the snake one step.
    Updates body, score, alive, and food in the state dict.
    """
    var dx     = Int(Float64(String(s["dx"])))
    var dy     = Int(Float64(String(s["dy"])))
    var head_x = Int(Float64(String(s["body_x"][0])))
    var head_y = Int(Float64(String(s["body_y"][0])))
    var grid_w = Int(Float64(String(s["grid_w"])))
    var grid_h = Int(Float64(String(s["grid_h"])))
    var food_x = Int(Float64(String(s["food_x"])))
    var food_y = Int(Float64(String(s["food_y"])))

    var new_x = head_x + dx
    var new_y = head_y + dy

    # Wall collision
    if new_x < 0 or new_x >= grid_w or new_y < 0 or new_y >= grid_h:
        s["alive"] = False
        return

    # Self collision
    var n = Int(Float64(String(len(s["body_x"]))))
    for i in range(n):
        var bx = Int(Float64(String(s["body_x"][i])))
        var by = Int(Float64(String(s["body_y"][i])))
        if bx == new_x and by == new_y:
            s["alive"] = False
            return

    # Insert new head
    s["body_x"].insert(0, new_x)
    s["body_y"].insert(0, new_y)

    # Food check
    if new_x == food_x and new_y == food_y:
        var score = Int(Float64(String(s["score"])))
        s["score"] = score + 10
        place_food(s)
    else:
        # Remove tail
        _ = s["body_x"].pop()
        _ = s["body_y"].pop()


fn draw_cell(canvas: PythonObject, x: Int, y: Int,
             color: String, cell: Int) raises:
    """Draw one grid cell as a filled rectangle."""
    var x1 = x * cell
    var y1 = y * cell
    _ = canvas.create_rectangle(
        x1, y1, x1 + cell, y1 + cell,
        fill=color, outline="#222222"
    )


fn render(canvas: PythonObject, s: PythonObject,
          cell: Int, win_w: Int, win_h: Int, auto_mode: Bool) raises:
    """Clear canvas and redraw all game elements."""
    canvas.delete("all")

    var food_x = Int(Float64(String(s["food_x"])))
    var food_y = Int(Float64(String(s["food_y"])))
    var score  = Int(Float64(String(s["score"])))
    var alive  = Bool(s["alive"])
    var n      = Int(Float64(String(len(s["body_x"]))))

    # Food
    draw_cell(canvas, food_x, food_y, "#FF4444", cell)

    # Snake body — cyan head in auto mode, green in manual
    for i in range(n):
        var bx    = Int(Float64(String(s["body_x"][i])))
        var by    = Int(Float64(String(s["body_y"][i])))
        var color: String
        if i == 0:
            color = "#00DDFF" if auto_mode else "#00EE55"
        else:
            color = "#0099BB" if auto_mode else "#00AA33"
        draw_cell(canvas, bx, by, color, cell)

    # Score label
    _ = canvas.create_text(
        6, 6, anchor="nw",
        text="Score: " + String(score),
        fill="white",
        font=Python.evaluate("('Arial', 12, 'bold')")
    )

    # Auto mode indicator (top-right)
    if auto_mode:
        _ = canvas.create_text(
            win_w - 6, 6, anchor="ne",
            text="AUTO  [A] to disable",
            fill="#00DDFF",
            font=Python.evaluate("('Arial', 11, 'bold')")
        )
    else:
        _ = canvas.create_text(
            win_w - 6, 6, anchor="ne",
            text="[A] Auto mode",
            fill="#888888",
            font=Python.evaluate("('Arial', 11)")
        )

    # Game over overlay
    if not alive:
        _ = canvas.create_text(
            win_w // 2, win_h // 2 - 24,
            text="GAME OVER",
            fill="#FF4444",
            font=Python.evaluate("('Arial', 30, 'bold')")
        )
        _ = canvas.create_text(
            win_w // 2, win_h // 2 + 18,
            text="Score: " + String(score) +
                 "    |    R = restart    |    Q = quit",
            fill="white",
            font=Python.evaluate("('Arial', 13)")
        )


fn run_game() raises:
    tk: PythonObject   = Python.import_module("tkinter")
    time: PythonObject = Python.import_module("time")

    var cell   = 20
    var grid_w = 30
    var grid_h = 25
    var win_w  = cell * grid_w
    var win_h  = cell * grid_h
    var fps_ms = 120

    # All game state in one Python dict
    var s: PythonObject = make_state(grid_w, grid_h)

    # --- Window setup ---
    root: PythonObject   = tk.Tk()
    root.title("Snake — Mojo + tkinter")
    root.resizable(False, False)
    canvas: PythonObject = tk.Canvas(
        root, width=win_w, height=win_h, bg="#111111"
    )
    canvas.pack()

    # Shared input state:
    # next_dir[0] : pending direction
    # flags[0]    : restart (R)
    # flags[1]    : quit (Q)
    # flags[2]    : toggle auto mode (A)
    next_dir: PythonObject = Python.evaluate("lambda: [3]")()
    flags: PythonObject    = Python.evaluate("lambda: [False, False, False]")()

    snake_helpers: PythonObject = Python.import_module("snake_helpers")
    var key_handler = snake_helpers.make_handler(next_dir, flags)

    root.bind("<KeyPress>", key_handler)
    root.focus_set()

    var auto_mode = False

    render(canvas, s, cell, win_w, win_h, auto_mode)
    root.update()

    while True:
        try:
            _ = root.winfo_exists()
        except:
            break

        if Bool(flags[1]):
            break

        if Bool(flags[0]):
            s = make_state(grid_w, grid_h)
            flags[0]    = False
            next_dir[0] = DIR_RIGHT

        # Toggle auto mode
        if Bool(flags[2]):
            auto_mode = not auto_mode
            flags[2]  = False

        if Bool(s["alive"]):
            if auto_mode:
                # BFS: find best next direction
                var bfs_dir = Int(Float64(String(
                    snake_helpers.bfs_next_dir(s)
                )))
                if bfs_dir >= 0:
                    set_direction(s, bfs_dir)
                # if bfs_dir == -1: no path, keep current direction
            else:
                var new_dir = Int(Float64(String(next_dir[0])))
                set_direction(s, new_dir)
            move_snake(s)

        render(canvas, s, cell, win_w, win_h, auto_mode)

        try:
            root.update()
        except:
            break

        # Auto mode runs faster (50ms), manual mode normal (120ms)
        var frame_ms = 50 if auto_mode else fps_ms
        var steps    = 6
        var step_ms  = frame_ms / steps
        for _ in range(steps):
            time.sleep(step_ms / 1000.0)
            try:
                root.update()
            except:
                break

    try:
        root.destroy()
    except:
        pass


fn main() raises:
    run_game()
