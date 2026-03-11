"""
Author: Ahmet Aksoy
Date: 2026-03-10
Revision Date: 2026-03-10
Mojo version no: 0.26.1
AI: Claude Sonnet 4.6

Description:
    Terminal-based number guessing game implemented in Mojo.

    The program picks a random integer between 1 and 100.
    The player has up to 10 attempts to guess the number.
    After each guess the program responds with 'Too high',
    'Too low', or 'Correct!'.
    At the end of the game the player is asked if they want
    to play again.

    No external packages are needed beyond Python's standard
    library (random, sys).
"""

from python import Python, PythonObject


fn get_random_number(low: Int, high: Int) raises -> Int:
    """Return a random integer in the closed range [low, high]."""
    random: PythonObject = Python.import_module("random")
    return Int(Float64(String(random.randint(low, high))))


fn get_guess(builtins: PythonObject) raises -> Int:
    """
    Read one line from stdin and parse it as an integer.
    Returns -1 if the input is not a valid integer.
    """
    var raw = String(builtins.input("  Your guess: "))
    var raw_stripped = raw.strip()
    # Try to parse — reject decimals and non-numeric input
    for ch in raw_stripped.codepoint_slices():
        if ch < "0" or ch > "9":
            return -1
    if len(raw_stripped) == 0:
        return -1
    return Int(raw_stripped)


fn play_round(builtins: PythonObject) raises -> Bool:
    """
    Run one round of the game.
    Returns True if the player wants to play again, False to quit.
    """
    comptime MAX_ATTEMPTS = 10
    comptime LOW  = 1
    comptime HIGH = 100

    var secret   = get_random_number(LOW, HIGH)
    var attempts = 0
    var won      = False

    print("\n" + "─" * 40)
    print("  I'm thinking of a number between "
          + String(LOW) + " and " + String(HIGH) + ".")
    print("  You have " + String(MAX_ATTEMPTS) + " attempts.")
    print("─" * 40)

    while attempts < MAX_ATTEMPTS:
        var remaining = MAX_ATTEMPTS - attempts
        print("\n  Attempts remaining: " + String(remaining))

        var guess = get_guess(builtins)

        if guess < LOW or guess > HIGH:
            print("  ⚠  Please enter a number between "
                  + String(LOW) + " and " + String(HIGH) + ".")
            continue

        attempts += 1

        if guess == secret:
            won = True
            break
        elif guess < secret:
            print("  📉 Too low!")
        else:
            print("  📈 Too high!")

    print("\n" + "─" * 40)
    if won:
        print("  🎉 Correct! The number was " + String(secret) + ".")
        print("  You got it in " + String(attempts) + " attempt(s).")
    else:
        print("  💀 Game over! The number was " + String(secret) + ".")
    print("─" * 40)

    # Ask to play again
    print("\n  Play again? (y / n): ", end="")
    var answer = String(builtins.input("")).strip().lower()
    return answer == "y" or answer == "yes"


fn main() raises:
    builtins: PythonObject = Python.import_module("builtins")

    print("\n" + "=" * 40)
    print("      NUMBER GUESSING GAME")
    print("=" * 40)

    while True:
        var play_again = play_round(builtins)
        if not play_again:
            break

    print("\n  Thanks for playing! Goodbye. 👋\n")
