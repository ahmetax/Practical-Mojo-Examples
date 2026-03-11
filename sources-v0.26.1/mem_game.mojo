"""
Author: Ahmet Aksoy
Date: 2026-03-10
Revision Date: 2026-03-10
Mojo version no: 0.26.1
AI: Claude Sonnet 4.6

Description:
    Terminal-based Memory Card Game implemented in Mojo using Python's
    tkinter library for the graphical interface.

    A 4x4 grid of face-down cards is displayed. Each card has a matching
    pair. The player clicks two cards per turn to reveal them. If they
    match, they stay face-up. If not, they flip back after a short delay.

    The game ends when all pairs are matched.
    Moves and elapsed time are tracked and displayed.

    Controls:
      Left click — flip a card
      R          — restart
      Q          — quit

Requirements:
    tkinter is included in Python's standard library.
    No additional packages needed.
"""

from python import Python, PythonObject

comptime COLS      = 4
comptime ROWS      = 4
comptime CARD_W    = 100
comptime CARD_H    = 100
comptime PAD       = 10
comptime WIN_W     = COLS * (CARD_W + PAD) + PAD
comptime WIN_H     = ROWS * (CARD_H + PAD) + PAD + 60  # extra for status bar


fn make_state(random: PythonObject) raises -> PythonObject:
    """
    Create a fresh game state dict.

    Keys:
      cards       : Python list of 16 symbol strings (shuffled pairs)
      revealed    : Python list of 16 bools — True if face-up/matched
      matched     : Python list of 16 bools — True if permanently matched
      first_idx   : index of first flipped card (-1 if none)
      moves       : total number of pairs attempted
      pairs_found : number of matched pairs
      locked      : bool — input blocked while mismatch animation runs
      start_time  : time.time() at game start
    """
    builtins: PythonObject = Python.import_module("builtins")
    time: PythonObject     = Python.import_module("time")

    # 8 pairs of symbols
    var symbols = builtins.list()
    symbols.append("🐶"); symbols.append("🐶")
    symbols.append("🐱"); symbols.append("🐱")
    symbols.append("🐭"); symbols.append("🐭")
    symbols.append("🐹"); symbols.append("🐹")
    symbols.append("🐰"); symbols.append("🐰")
    symbols.append("🦊"); symbols.append("🦊")
    symbols.append("🐻"); symbols.append("🐻")
    symbols.append("🐼"); symbols.append("🐼")

    # Shuffle
    var cards = random.sample(symbols, builtins.len(symbols))

    # revealed and matched: 16 x False
    var revealed = builtins.list()
    var matched  = builtins.list()
    for i in range(16):
        revealed.append(False)
        matched.append(False)

    var s = Python.dict()
    s["cards"]       = cards
    s["revealed"]    = revealed
    s["matched"]     = matched
    s["first_idx"]   = -1
    s["moves"]       = 0
    s["pairs_found"] = 0
    s["locked"]      = False
    s["start_time"]  = time.time()
    return s


fn card_x(idx: Int) -> Int:
    """Return the left pixel coordinate of card at grid index idx."""
    var col = idx % COLS
    return PAD + col * (CARD_W + PAD)


fn card_y(idx: Int) -> Int:
    """Return the top pixel coordinate of card at grid index idx."""
    var row = idx // COLS
    return PAD + row * (CARD_H + PAD)


fn draw_card(canvas: PythonObject, idx: Int,
             symbol: String, face_up: Bool, is_matched: Bool) raises:
    """Draw a single card on the canvas."""
    var x   = card_x(idx)
    var y   = card_y(idx)
    var x2  = x + CARD_W
    var y2  = y + CARD_H
    var cx  = x + CARD_W // 2
    var cy  = y + CARD_H // 2

    var bg_color: String
    if is_matched:
        bg_color = "#2ecc71"   # green — permanently matched
    elif face_up:
        bg_color = "#3498db"   # blue — currently revealed
    else:
        bg_color = "#2c3e50"   # dark — face down

    _ = canvas.create_rectangle(
        x, y, x2, y2,
        fill=bg_color, outline="#1a252f", width=2
    )

    if face_up or is_matched:
        _ = canvas.create_text(
            cx, cy,
            text=symbol,
            font=Python.evaluate("('Arial', 36)")
        )
    else:
        _ = canvas.create_text(
            cx, cy,
            text="?",
            fill="#7f8c8d",
            font=Python.evaluate("('Arial', 32, 'bold')")
        )


fn render(canvas: PythonObject, s: PythonObject,
          win_w: Int, win_h: Int) raises:
    """Redraw the full game canvas."""
    canvas.delete("all")

    var n           = 16
    var pairs_found = Int(Float64(String(s["pairs_found"])))
    var moves       = Int(Float64(String(s["moves"])))

    # Draw all cards
    for i in range(n):
        var symbol    = String(s["cards"][i])
        var face_up   = Bool(s["revealed"][i])
        var is_matched = Bool(s["matched"][i])
        draw_card(canvas, i, symbol, face_up, is_matched)

    # Status bar background
    var bar_y = win_h - 55
    _ = canvas.create_rectangle(
        0, bar_y, win_w, win_h,
        fill="#1a252f", outline=""
    )

    # Moves and pairs
    _ = canvas.create_text(
        PAD, bar_y + 18, anchor="nw",
        text="Moves: " + String(moves),
        fill="white",
        font=Python.evaluate("('Arial', 12, 'bold')")
    )
    _ = canvas.create_text(
        PAD, bar_y + 36, anchor="nw",
        text="Pairs: " + String(pairs_found) + " / 8",
        fill="#2ecc71",
        font=Python.evaluate("('Arial', 12, 'bold')")
    )

    # Controls hint
    _ = canvas.create_text(
        win_w - PAD, bar_y + 27, anchor="ne",
        text="R = restart   Q = quit",
        fill="#7f8c8d",
        font=Python.evaluate("('Arial', 11)")
    )

    # Win overlay
    if pairs_found == 8:
        time: PythonObject = Python.import_module("time")
        var elapsed = Float64(String(time.time())) - Float64(String(s["start_time"]))
        var secs    = Int(elapsed)
        _ = canvas.create_rectangle(
            40, win_h // 2 - 70, win_w - 40, win_h // 2 + 70,
            fill="#1a252f", outline="#2ecc71", width=3
        )
        _ = canvas.create_text(
            win_w // 2, win_h // 2 - 35,
            text="🎉 You Win!",
            fill="#2ecc71",
            font=Python.evaluate("('Arial', 28, 'bold')")
        )
        _ = canvas.create_text(
            win_w // 2, win_h // 2 + 10,
            text="Moves: " + String(moves) + "   Time: " + String(secs) + "s",
            fill="white",
            font=Python.evaluate("('Arial', 14)")
        )
        _ = canvas.create_text(
            win_w // 2, win_h // 2 + 45,
            text="R = play again",
            fill="#7f8c8d",
            font=Python.evaluate("('Arial', 12)")
        )


fn on_card_click(s: PythonObject, idx: Int) raises:
    """
    Handle a card click at grid index idx.
    Updates state dict in place.
    """
    # Ignore if locked, already matched, or same card clicked twice
    if Bool(s["locked"]):
        return
    if Bool(s["matched"][idx]):
        return
    if Bool(s["revealed"][idx]):
        return

    var first_idx = Int(Float64(String(s["first_idx"])))

    # Flip this card
    s["revealed"][idx] = True

    if first_idx == -1:
        # First card of the pair
        s["first_idx"] = idx
    else:
        # Second card — check for match
        s["moves"] = Int(Float64(String(s["moves"]))) + 1
        s["first_idx"] = -1

        var sym_a = String(s["cards"][first_idx])
        var sym_b = String(s["cards"][idx])

        if sym_a == sym_b:
            # Match!
            s["matched"][first_idx] = True
            s["matched"][idx]       = True
            s["pairs_found"] = Int(Float64(String(s["pairs_found"]))) + 1
        else:
            # No match — lock input and schedule flip-back via flag
            s["locked"]     = True
            s["flip_a"]     = first_idx
            s["flip_b"]     = idx


fn run_game() raises:
    tk: PythonObject     = Python.import_module("tkinter")
    time: PythonObject   = Python.import_module("time")
    random: PythonObject = Python.import_module("random")

    var win_w = WIN_W
    var win_h = WIN_H

    var s: PythonObject = make_state(random)

    # --- Window ---
    root: PythonObject   = tk.Tk()
    root.title("Memory Game — Mojo + tkinter")
    root.resizable(False, False)

    canvas: PythonObject = tk.Canvas(
        root, width=win_w, height=win_h, bg="#2c3e50"
    )
    canvas.pack()

    # Shared flags: flags[0]=restart, flags[1]=quit, flags[2]=click_idx(-1=none)
    flags: PythonObject = Python.evaluate("lambda: [False, False, -1]")()

    # Key handler
    mem_helpers: PythonObject = Python.import_module("mem_helpers")
    var key_handler   = mem_helpers.make_key_handler(flags)
    var click_handler = mem_helpers.make_click_handler(
        flags, win_w, win_h,
        CARD_W, CARD_H, PAD, COLS, ROWS
    )

    root.bind("<KeyPress>", key_handler)
    canvas.bind("<Button-1>", click_handler)
    root.focus_set()

    render(canvas, s, win_w, win_h)
    root.update()

    # Mismatch flip-back timer
    var flip_back_time: Float64 = 0.0
    var waiting_flip   = False

    while True:
        try:
            _ = root.winfo_exists()
        except:
            break

        if Bool(flags[1]):
            break

        if Bool(flags[0]):
            s = make_state(random)
            flags[0] = False
            waiting_flip = False

        # Handle flip-back after mismatch delay (0.7s)
        if waiting_flip:
            var now = Float64(String(time.time()))
            if now >= flip_back_time:
                var fa = Int(Float64(String(s["flip_a"])))
                var fb = Int(Float64(String(s["flip_b"])))
                s["revealed"][fa] = False
                s["revealed"][fb] = False
                s["locked"]       = False
                waiting_flip      = False

        # Handle card click
        var click_idx = Int(Float64(String(flags[2])))
        if click_idx >= 0:
            flags[2] = -1
            on_card_click(s, click_idx)
            # If locked after click, start flip-back timer
            if Bool(s["locked"]):
                var now       = Float64(String(time.time()))
                flip_back_time = now + 0.7
                waiting_flip   = True

        render(canvas, s, win_w, win_h)

        try:
            root.update()
        except:
            break

        time.sleep(0.03)

    try:
        root.destroy()
    except:
        pass


fn main() raises:
    run_game()
