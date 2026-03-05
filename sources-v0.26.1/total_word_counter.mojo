"""
Author: Ahmet Aksoy
Date: 2026-02-24
Revision Date: 2026-02-25
Mojo version no: 0.26.1
"""

from pathlib import Path
from builtin.sort import sort
from time import perf_counter_ns

struct FileCounter:
    var count: UInt
    var total_words: Int
    var read_time: UInt      # nanosaniye
    var extract_time: UInt   # nanosaniye
    var process_time: UInt   # nanosaniye
    
    fn __init__(out self):
        self.count = 0
        self.total_words = 0
        self.read_time = 0
        self.extract_time = 0
        self.process_time = 0
    
    fn print_times(self):
        print("\n=== TIME ANALYSIS ===")
        print("Reading:    ", self.read_time // 1_000_000, "ms")
        print("Filtering: ", self.extract_time // 1_000_000, "ms")
        print("Processing:   ", self.process_time // 1_000_000, "ms")
        print("Total:          ", (self.read_time + self.extract_time + self.process_time) // 1_000_000, "ms")

struct WordCount(Comparable & Copyable & Movable):
    var word: String
    var count: Int
    
    fn __init__(out self, word: String, count: Int):
        self.word = word
        self.count = count
    
    fn __copyinit__(out self, other: Self):
        self.word = other.word
        self.count = other.count
    
    fn __moveinit__(out self, deinit other: Self):
        self.word = other.word^
        self.count = other.count
    
    fn __lt__(self, other: Self) -> Bool:
        return self.count > other.count
    
    fn __le__(self, other: Self) -> Bool:
        return self.count >= other.count
    
    fn __gt__(self, other: Self) -> Bool:
        return self.count < other.count
    
    fn __ge__(self, other: Self) -> Bool:
        return self.count <= other.count
    
    fn __eq__(self, other: Self) -> Bool:
        return self.count == other.count
    
    fn __ne__(self, other: Self) -> Bool:
        return self.count != other.count

fn tr_lower(word: String) -> String:
    var nword: String = word
    nword = nword.replace("İ", "i")
    nword = nword.replace("I", "ı")
    return nword.lower()

fn tr_upper(word: String) -> String:
    var nword: String = word
    nword = nword.replace("i", "İ")
    nword = nword.replace("ı", "I")
    return nword.upper()

fn print_top_words(word_freq: Dict[String, Int], top_n: Int) raises:
    var items = List[WordCount]()
    
    for item in word_freq.items():
        items.append(WordCount(item.key, item.value))
    
    sort(items)
    
    print("\n=== MOST USED", top_n, "WORDS ===")
    for i in range(min(top_n, len(items))):
        print(i + 1, ".", items[i].word, "->", items[i].count, "times")

fn extract_turkish_body(mut text: String) -> String:
    var start_marker:String = "*** START OF TURKISH PART ***\n"
    var end_marker:String = "*** END OF TURKISH PART ***\n"
    
    var start = text.find(start_marker)
    var end = text.find(end_marker)
    
    # Marker bulunamazsa tüm metni döndür
    if start == -1 or end == -1:
        return String(text)
    
    # Marker sonrasından başla
    start = start + len(start_marker)
    
    return String(text[start:end])

fn process_file(filepath: String, mut word_freq: Dict[String, Int], mut counter: FileCounter) raises:
    var t1 = perf_counter_ns()
    var f = open(filepath, "r")
    var content = f.read()
    f.close()
    var t2 = perf_counter_ns()
    
    var turkish_text = extract_turkish_body(content)
    # turkish_text = turkish_text.lower() # Takes longer
    # Remove punctuation chars
    turkish_text = turkish_text.replace(".", " ")
    turkish_text = turkish_text.replace(",", " ")
    turkish_text = turkish_text.replace("!", " ")
    turkish_text = turkish_text.replace("?", " ")
    turkish_text = turkish_text.replace(";", " ")
    turkish_text = turkish_text.replace(":", " ")
    turkish_text = turkish_text.replace("'", "")
    turkish_text = turkish_text.replace('"', " ")
    turkish_text = turkish_text.replace("(", " ")
    turkish_text = turkish_text.replace(")", " ")
    var t3 = perf_counter_ns()
    
    var words = turkish_text.split()
    for i in range(len(words)):
        var word = tr_lower(String(words[i]))
        if len(word) == 0:
            continue
        word_freq[word] = word_freq.get(word, 0) + 1
    var t4 = perf_counter_ns()
    
    counter.read_time += t2 - t1
    counter.extract_time += t3 - t2
    counter.process_time += t4 - t3

fn scan_txt_files(path: Path, mut word_freq: Dict[String, Int], mut counter: FileCounter, max_files: UInt = 0) raises:
    var entries = path.listdir()
    
    for i in range(len(entries)):
        if max_files > 0 and counter.count >= max_files:  # Limit control
                return
                
        # if i % 10 == 0:
        #     print(i, "/", len(entries), "files processed")

        var entry_name = entries[i]
        var entry_path = path / entry_name
        
        if entry_path.is_dir():
            scan_txt_files(entry_path, word_freq, counter, max_files)
        elif entry_path.is_file() and String(entry_name)[-4:] == ".txt":
            counter.count += 1
            # print("İşleniyor [", counter.count, "/", max_files, "]:", entry_path)
            print(entry_path)
            process_file(String(entry_path), word_freq, counter)

fn test_read_only(filepath: String, mut counter: FileCounter) raises:
    var t1 = perf_counter_ns()
    var f = open(filepath, "r")
    var content = f.read()
    f.close()
    var t2 = perf_counter_ns()
    counter.read_time += t2 - t1

fn main() raises:
    var word_freq = Dict[String, Int]()
    var counter = FileCounter()
    var path = Path("./gutenberg_org/")
    
    var t_start = perf_counter_ns()
    scan_txt_files(path, word_freq, counter)   # all files

    print("Processed files:", counter.count)
    print("Total unique words:", len(word_freq))
    counter.print_times()
    
    var t_sort_start = perf_counter_ns()
    print_top_words(word_freq, 30)
    var t_sort_end = perf_counter_ns()
    
    print("\nSorting time:  ", (t_sort_end - t_sort_start) // 1_000_000, "ms")
    print("Total time: ", (t_sort_end - t_start) // 1_000_000, "ms")


