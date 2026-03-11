"""
Snake game keyboard handler and AI helper.
Imported by snake_game.mojo via Python.import_module().
"""

from collections import deque


def make_handler(nd, fl):
    def on_key(e):
        k = e.keysym
        if   k == 'Up':       nd[0] = 0
        elif k == 'Down':     nd[0] = 1
        elif k == 'Left':     nd[0] = 2
        elif k == 'Right':    nd[0] = 3
        elif k in ('r', 'R'): fl[0] = True
        elif k in ('q', 'Q'): fl[1] = True
        elif k in ('a', 'A'): fl[2] = True  # toggle auto mode
    return on_key


def bfs_next_dir(s):
    """
    BFS (Breadth First Search) from snake head to food.
    Returns the first direction to take (0=UP, 1=DOWN, 2=LEFT, 3=RIGHT),
    or -1 if no path found (snake will continue straight).

    Body cells are treated as walls. The tail is excluded because
    it will have moved away by the time we reach that cell.
    """
    grid_w = int(s["grid_w"])
    grid_h = int(s["grid_h"])
    bx     = list(s["body_x"])
    by     = list(s["body_y"])
    food_x = int(s["food_x"])
    food_y = int(s["food_y"])
    hx     = int(bx[0])
    hy     = int(by[0])

    # Obstacle set: all body cells except the tail (tail moves away next step)
    obstacles = set()
    for i in range(len(bx) - 1):
        obstacles.add((int(bx[i]), int(by[i])))

    # BFS — each item: (x, y, first_direction_taken)
    # Directions: UP=0, DOWN=1, LEFT=2, RIGHT=3
    deltas  = [(0, -1), (0, 1), (-1, 0), (1, 0)]
    queue   = deque()
    visited = set()
    visited.add((hx, hy))

    for d, (ddx, ddy) in enumerate(deltas):
        nx, ny = hx + ddx, hy + ddy
        if 0 <= nx < grid_w and 0 <= ny < grid_h:
            if (nx, ny) not in obstacles and (nx, ny) not in visited:
                visited.add((nx, ny))
                queue.append((nx, ny, d))

    while queue:
        x, y, first_dir = queue.popleft()
        if x == food_x and y == food_y:
            return first_dir
        for ddx, ddy in deltas:
            nx, ny = x + ddx, y + ddy
            if 0 <= nx < grid_w and 0 <= ny < grid_h:
                if (nx, ny) not in obstacles and (nx, ny) not in visited:
                    visited.add((nx, ny))
                    queue.append((nx, ny, first_dir))

    return -1  # no path — keep going straight
