"""
Author: Ahmet Aksoy
Date: 2026-03-10
Revision Date: 2026-03-10
Mojo version no: 0.26.1
AI: Claude Sonnet 4.6

Description:
    Terminal-based word guessing (Hangman) game implemented in Mojo.

    A word is chosen at random from a built-in word list.
    The player guesses one letter at a time.
    Correct letters are revealed in their positions.
    The player has 6 wrong guesses before the game is lost.
    A simple ASCII hangman figure is drawn as wrong guesses accumulate.

    No external packages are needed beyond Python's standard library.
"""

from python import Python, PythonObject


# ASCII hangman stages (0 = none, 6 = full figure)
fn hangman_art(stage: Int) -> String:
    if stage == 0:
        return (
            "  +---+\n"
            "  |   |\n"
            "      |\n"
            "      |\n"
            "      |\n"
            "      |\n"
            "=========\n"
        )
    elif stage == 1:
        return (
            "  +---+\n"
            "  |   |\n"
            "  O   |\n"
            "      |\n"
            "      |\n"
            "      |\n"
            "=========\n"
        )
    elif stage == 2:
        return (
            "  +---+\n"
            "  |   |\n"
            "  O   |\n"
            "  |   |\n"
            "      |\n"
            "      |\n"
            "=========\n"
        )
    elif stage == 3:
        return (
            "  +---+\n"
            "  |   |\n"
            "  O   |\n"
            " /|   |\n"
            "      |\n"
            "      |\n"
            "=========\n"
        )
    elif stage == 4:
        return (
            "  +---+\n"
            "  |   |\n"
            "  O   |\n"
            " /|\\  |\n"
            "      |\n"
            "      |\n"
            "=========\n"
        )
    elif stage == 5:
        return (
            "  +---+\n"
            "  |   |\n"
            "  O   |\n"
            " /|\\  |\n"
            " /    |\n"
            "      |\n"
            "=========\n"
        )
    else:
        return (
            "  +---+\n"
            "  |   |\n"
            "  O   |\n"
            " /|\\  |\n"
            " / \\  |\n"
            "      |\n"
            "=========\n"
        )


fn get_word(builtins: PythonObject) raises -> String:
    """Pick a random word from the built-in word list."""
    random: PythonObject = Python.import_module("random")

    var words = List[String]()
    words.append("python")
    words.append("mojo")
    words.append("programming")
    words.append("keyboard")
    words.append("algorithm")
    words.append("variable")
    words.append("function")
    words.append("compiler")
    words.append("terminal")
    words.append("iterator")
    words.append("exception")
    words.append("interface")
    words.append("recursion")
    words.append("bandwidth")
    words.append("debugging")
    words.append("framework")
    words.append("parameter")
    words.append("encrypted")
    words.append("processor")
    words.append("directory")

    var idx = Int(Float64(String(random.randint(0, len(words) - 1))))
    return words[idx]


fn build_display(word: String, guessed: List[String]) -> String:
    """
    Build the display string for the current word state.
    Revealed letters are shown, unguessed letters shown as '_'.
    """
    var display = String("")
    for ch in word.codepoint_slices():
        var found = False
        for i in range(len(guessed)):
            if guessed[i] == String(ch):
                found = True
                break
        if found:
            display += String(ch) + " "
        else:
            display += "_ "
    return display


fn is_solved(word: String, guessed: List[String]) -> Bool:
    """Return True when every letter in the word has been guessed."""
    for ch in word.codepoint_slices():
        var found = False
        for i in range(len(guessed)):
            if guessed[i] == String(ch):
                found = True
                break
        if not found:
            return False
    return True


fn play_round(builtins: PythonObject) raises -> Bool:
    """
    Run one round of the game.
    Returns True if the player wants to play again, False to quit.
    """
    comptime MAX_WRONG = 6

    var word        = get_word(builtins)
    var wrong       = 0
    var guessed     = List[String]()
    var wrong_list  = List[String]()

    print("\n" + "=" * 40)
    print("       WORD GUESSING GAME")
    print("=" * 40)
    print("  Guess the " + String(len(word)) + "-letter word!")

    while wrong < MAX_WRONG:
        print("\n" + hangman_art(wrong))
        print("  Word:   " + build_display(word, guessed))

        # Show wrong guesses
        var wrong_str = String("")
        for i in range(len(wrong_list)):
            wrong_str += wrong_list[i]
            if i < len(wrong_list) - 1:
                wrong_str += ", "
        if len(wrong_list) > 0:
            print("  Wrong:  " + wrong_str)
        print("  Remaining wrong guesses: "
              + String(MAX_WRONG - wrong))

        # Check win before asking for input
        if is_solved(word, guessed):
            break

        # Get input
        print("\n  Enter a letter: ", end="")
        var raw = String(builtins.input("")).strip().lower()

        if len(raw) != 1:
            print("  ⚠  Please enter a single letter.")
            continue

        var letter = raw

        # Check if already guessed
        var already = False
        for i in range(len(guessed)):
            if guessed[i] == letter:
                already = True
                break
        if already:
            print("  ⚠  You already guessed '" + letter + "'.")
            continue

        guessed.append(letter)

        # Check if letter is in word
        var hit = False
        for ch in word.codepoint_slices():
            if String(ch) == letter:
                hit = True
                break

        if hit:
            print("  ✓  Good guess!")
        else:
            wrong += 1
            wrong_list.append(letter)
            print("  ✗  Wrong!")

        if is_solved(word, guessed):
            break

    # Result
    print("\n" + hangman_art(wrong))
    if is_solved(word, guessed):
        print("  🎉 You won! The word was: " + word)
    else:
        print("  💀 Game over! The word was: " + word)
    print("=" * 40)

    print("\n  Play again? (y / n): ", end="")
    var answer = String(builtins.input("")).strip().lower()
    return answer == "y" or answer == "yes"


fn main() raises:
    builtins: PythonObject = Python.import_module("builtins")

    while True:
        var play_again = play_round(builtins)
        if not play_again:
            break

    print("\n  Thanks for playing! Goodbye. 👋\n")
