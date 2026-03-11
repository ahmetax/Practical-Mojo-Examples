"""
Memory Game keyboard and mouse click handler helper.
Imported by mem_game.mojo via Python.import_module().
"""


def make_key_handler(flags):
    def on_key(event):
        k = event.keysym
        if k in ('r', 'R'):   flags[0] = True
        elif k in ('q', 'Q'): flags[1] = True
    return on_key


def make_click_handler(flags, win_w, win_h, card_w, card_h, pad, cols, rows):
    def on_click(event):
        x, y = event.x, event.y
        # Determine which card was clicked
        for row in range(rows):
            for col in range(cols):
                cx = pad + col * (card_w + pad)
                cy = pad + row * (card_h + pad)
                if cx <= x <= cx + card_w and cy <= y <= cy + card_h:
                    idx = row * cols + col
                    flags[2] = idx
                    return
    return on_click
