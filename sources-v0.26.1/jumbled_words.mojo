"""
Author: Ahmet Aksoy
Date: 2026-03-10
Revision Date: 2026-03-10
Mojo version no: 0.26.1
AI: Claude Sonnet 4.6

Description:
    Terminal-based jumbled words game implemented in Mojo.

    A word is chosen at random from a built-in word list and its
    letters are shuffled. The player must figure out the original
    word from the jumbled version.

    The player has 3 attempts per word. A hint (first letter) can
    be requested once per round by typing '?'.
    Typing 'skip' moves on to the next word without penalty.

    No external packages are needed beyond Python's standard library.
"""

from python import Python, PythonObject


fn get_word(random: PythonObject) raises -> String:
    """Pick a random word from the built-in word list."""
    builtins: PythonObject = Python.import_module("builtins")

    var py_words: PythonObject = builtins.list()
    py_words.append("python")
    py_words.append("mojo")
    py_words.append("keyboard")
    py_words.append("algorithm")
    py_words.append("variable")
    py_words.append("function")
    py_words.append("compiler")
    py_words.append("terminal")
    py_words.append("iterator")
    py_words.append("exception")
    py_words.append("interface")
    py_words.append("recursion")
    py_words.append("bandwidth")
    py_words.append("debugging")
    py_words.append("framework")
    py_words.append("parameter")
    py_words.append("encrypted")
    py_words.append("processor")
    py_words.append("directory")
    py_words.append("condition")
    py_words.append("structure")
    py_words.append("abstraction")
    py_words.append("inheritance")
    py_words.append("polymorphism")
    py_words.append("encapsulation")

    # Use Python's len() and randint to stay on the Python side
    var n   = Int(Float64(String(builtins.len(py_words))))
    var idx = Int(Float64(String(random.randint(0, n - 1))))
    return String(py_words[idx])


fn jumble(word: String, random: PythonObject) raises -> String:
    """
    Shuffle the letters of a word using Python's random.sample().
    Ensures the jumbled version is different from the original.
    Tries up to 10 times before giving up and returning as-is.
    """
    var letters = List[String]()
    for ch in word.codepoint_slices():
        letters.append(String(ch))

    var n = len(letters)

    # Build a Python list for random.sample()
    builtins: PythonObject = Python.import_module("builtins")
    var py_letters: PythonObject = builtins.list()
    for i in range(n):
        py_letters.append(letters[i])

    var attempts = 0
    while attempts < 10:
        var shuffled = random.sample(py_letters, n)
        var result = String("")
        for i in range(n):
            result += String(shuffled[i])
        if result != word:
            return result
        attempts += 1

    return word  # fallback (very short words like "ab")


fn play_round(
    builtins: PythonObject,
    random: PythonObject,
    state: PythonObject
) raises -> Bool:
    """
    Run one round (one word).
    Updates state['score'] in place via Python dict reference.
    Returns True if the player wants to continue, False to quit.
    """
    comptime MAX_ATTEMPTS = 3

    var word    = get_word(random)
    var jumbled = jumble(word, random)
    var hint_used = False
    var attempts  = 0
    var solved    = False
    var skipped   = False

    print("\n" + "─" * 42)
    print("  Jumbled:  " + jumbled.upper())
    print("  Letters:  " + String(len(word)))
    print("─" * 42)

    while attempts < MAX_ATTEMPTS:
        var remaining = MAX_ATTEMPTS - attempts
        print("\n  Attempts remaining: " + String(remaining))

        # word[0] causes __getitem__ error — use codepoint_slices instead
        var first_letter = String("")
        for ch in word.codepoint_slices():
            first_letter = String(ch)
            break

        if hint_used:
            print("  Hint: first letter is '" + first_letter + "'")
        else:
            print("  Type '?' for a hint, 'skip' to skip.")

        print("  Your answer: ", end="")
        var raw = String(builtins.input("")).strip().lower()

        if raw == "skip":
            skipped = True
            break

        if raw == "?":
            if not hint_used:
                hint_used = True
                print("  💡 Hint: the first letter is '" + first_letter + "'")
            else:
                print("  ⚠  Hint already used.")
            continue

        if len(raw) == 0:
            print("  ⚠  Please enter a word.")
            continue

        attempts += 1

        if raw == word:
            solved = True
            break
        else:
            print("  ✗  Not quite. Try again!")

    # Result for this round
    var score = Int(Float64(String(state["score"])))
    print("\n" + "─" * 42)
    if solved:
        var points = 30 if not hint_used else 10
        score += points
        state["score"] = score
        print("  🎉 Correct! +" + String(points) + " points")
    elif skipped:
        print("  ⏭  Skipped. The word was: " + word)
    else:
        print("  💀 Out of attempts! The word was: " + word)
    print("  Total score: " + String(score))
    print("─" * 42)

    print("\n  Next word? (y / n): ", end="")
    var answer = String(builtins.input("")).strip().lower()
    return answer == "y" or answer == "yes"


fn main() raises:
    builtins: PythonObject = Python.import_module("builtins")
    random: PythonObject   = Python.import_module("random")

    print("\n" + "=" * 42)
    print("         JUMBLED WORDS GAME")
    print("=" * 42)
    print("  Unscramble the word to score points.")
    print("  Correct without hint : 30 pts")
    print("  Correct with hint    : 10 pts")
    print("=" * 42)

    var state: PythonObject = Python.dict()
    state["score"] = 0

    while True:
        var keep_going = play_round(builtins, random, state)
        if not keep_going:
            break

    var final_score = Int(Float64(String(state["score"])))

    print("\n" + "=" * 42)
    print("  Final score: " + String(final_score))
    print("  Thanks for playing! Goodbye. 👋")
    print("=" * 42 + "\n")
