# Practical-Mojo-Examples
Practical Mojo Examples Especially For Beginners

In this repository I will try to share some practical and tested mojo examples.
My examples are written and tested on an Ubuntu machine.
These examples are generally for the beginner level.
Maybe in future I can also share some advanced examples.

I preferred pip installation of mojo. For the other installation methods
please refer to https://docs.modular.com/mojo/manual/install page.
My Python version is Python 3.12.

We will use the text files in gutenberg_org in some of our examples. These
files are shared in https://gutenberg.org and selected randomly.

## Cloning
mkdir github

cd github

git clone https://github.com/ahmetax/Practical-Mojo-Examples.git

cd Practical-Mojo-Examples

## Mojo Installation
python3.12 -m venv e312

source e312/bin/activate

pip install mojo

cd sources-v0.26.1

pip install -r requirements.txt

## Version check

mojo -v

## You can share your own examples

If you wish, you can share your own mojo examples also.
You can use a header on top of your code as follows:

"""

Author: Your name

Date: Creation date

Revision Date: Revision date

Mojo version no: x.y.z

AI: ?

"""

## Code List And Explanations

It is not very easy to get the topic of the codes just looking their names.

I will remove version numbers from file names, and transfer the source files
into sources-v0.26.1 folder.  I hope it will be more readable.

Version numbers of Mojo used while testing example codes will be included both in the table, and in the headers in the files.

Here is the table

| <b>Explanation</b> | <b>Category</b> | <b>Mojo version</b> | <b>Code name</b> |
| :------------------------------------ | :----------| :-------------: | :--------------------------------------------- |
| Calculation of PI number | Pi | 0.26.1 | calculate_pi.mojo |
| Check if a number is Armstrong Number  or not | Armastrong number| 0.26.1 | check_armstrong_number.mojo |
| Prepare a countdown counter | Counter | 0.26.1 | countdown.mojo |
| Calculate factorial of a number | Factorial | 0.26.1 | factorial.mojo |
| Calculate Fibonacci number | Fibonacci | 0.26.1 | fibonacci.mojo |
| File and word counter for the files in a folder | Counter | 0.26.1 | file_and_word_counter_01.mojo |
| Printing "Hello World" | Hello World| 0.26.1 | hello_world.mojo |
| Using implicit typing | | 0.26.1 | implicit_types_01.mojo |
| List comprehensions | List comprehension| 0.26.1 | list_comprehensions.mojo |
| Multiply two integer numbers | Multiplication | 0.26.1 | multiply_01.mojo |
| Simple check for parallelize | Parallelize | 0.26.1 | parallelize_check_mojo |
| Using parallelize() method in order to read multiple files simultaneously | Parallelize | 0.26.1 |  parallelize_file_read.mojo |
| Using parallelize() method in order to read some multiple Turkish files simultaneously | Parallelize  | 0.26.1 |  parallelize_turkish_files.mojo |
| Printing prime numbers between 0 and 127 | Prime numbers| 0.26.1 | prime_numbers.mojo |
| Importing and using Python time module | Time | 0.26.1 | python_time.mojo |
| Read multiple files in given folder | Files | 0.26.1 | read_files.mojo |
| Reversing a list | Lists | 0.26.1 | reverse_a_list.mojo |
| Sort a dict by values Dict sort | Sort | 0.26.1 | sort_dict_01.mojo |
| Sort integers in a list in ascending and descending orders | Sort | 0.26.1 | sort_integers_01.mojo |
| Sort integers in a list by sort() | Sort | 0.26.1 | sort_integers_02.mojo |
| Simple sort for word count | Sort | 0.26.1 | sort_word_count.mojo |
| Simple sum of an array | Sum | 0.26.1 | sum_of_array.mojo |
| Using time module | Time | 0.26.1 |time_module.mojo |
| Word counting in files | Files | 0.26.1 | total_word_counter.mojo |
| Turkish lower and upper correction | Turkish chars | 0.26.1 | tr_lower_upper.mojo |
| Printing values in a list | Lists | 0.26.1 | vals_in_list_01.mojo |
| Testing Dict in word counter | Dicts | 0.26.1 | word_counter_dict_test.mojo |
| Summarize a file using Python modules | Summarize | 0.26.1 | summary_python.mojo |
| Collecting rss news from different countries using Python modules | News | 0.26.1 | rss_news_with_python.mojo |
| Cloning (copying) a list | Lists | 0.26.1 | clone_a_list.mojo |
| Simple sum of an array (using SIMD) |SIMD| 0.26.1 | simple_sum_of_an_array.mojo |
| Python numpy example |Numpy| 0.26.1 | python_numpy_01.mojo |
| Python request and json using http get |Requests| 0.26.1 | http_get_json_api.mojo |
| Python request and json using http post |Requests | 0.26.1 | http_post_json.mojo |
| Python request and json using http auth |Requests | 0.26.1 | http_auth_headers.mojo |
| Managing HTTP sessions in Mojo using Python's requests.Session object. |Requests| 0.26.1 | http_session.mojo |
| Handling timeouts and automatic retries for HTTP requests in Mojo.  |Requests| 0.26.1 | http_timeout_retry.mojo |
| Downloading files efficiently using HTTP streaming in Mojo. |Files| 0.26.1 | http_download_streaming.mojo |
| Common pitfalls when using Python modules and objects in Mojo. |Gotchas| 0.26.1 | python_interop_gotchas.md |
| Introduction to PythonObject — Mojo's explicit type for Python values |PythonObjects| 0.26.1 | python_object_basics.mojo |
| Collecting system information in Mojo using Python's os, platform, and psutil modules with explicit PythonObject typing (Style B). |PythonObjects | 0.26.1 | system_info.mojo |
| Reading and processing CSV files in Mojo using PythonObject (Style B). |PythonObjects | 0.26.1 | csv_processing.mojo |
| Image processing in Mojo using NumPy and Pillow via PythonObject. |PythonObjects | 0.26.1 | numpy_image_processing.mojo img_helpers.py |
| Data preprocessing for machine learning in Mojo using NumPy via PythonObject. |PythonObjects | 0.26.1 | numpy_ml_preprocessing.mojo ml_helpers.py |
| Frequency analysis of vibration sensor data using NumPy FFT in Mojo. |Numpy| 0.26.1 | numpy_fft.mojo fft_helpers.py |
| Time series analysis in Mojo using NumPy via PythonObject. |Numpy| 0.26.1 | numpy_time_series.mojo ts_helpers.py |
| Classic Snake game implemented in Mojo using Python's tkinter library. |Games| 0.26.1 | snake_game.mojo snake_helpers.py |
| Terminal-based number guessing game implemented in Mojo. |Games | 0.26.1 | number_guessing.mojo |
| Terminal-based word guessing (Hangman) game implemented in Mojo. |Games | 0.26.1 | word_guessing.mojo |
| Terminal-based jumbled words game implemented in Mojo. |Games | 0.26.1 | jumbled_words.mojo |
| Terminal-based Memory Card Game implemented in Mojo using Python's tkinter library for the graphical interface. |Games | 0.26.1 | mem_games.mojo mem_helpers.py |
| Minimal Flask web server started from Mojo via Python interop.| Flask | 0.26.1 | flask_hello.mojo flask_helpers.py |
| A simple REST API built with Mojo + Flask + SQLite. | Flask Sqlite | 0.26.1 | flask_sqlite_api.mojo flask_sqlite_helpers.py |
| SQLite database access from Mojo using Python's sqlite3 module. | SQLite | sqlite_crud.mojo |
| File-based SQLite database access from Mojo using Python's sqlite3 module. | SQLite | 0.26.1 | sqlite_crud.mojo |

