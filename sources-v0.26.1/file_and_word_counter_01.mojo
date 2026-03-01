from pathlib import Path

struct FileCounter:
    "Used to count total # of files and words."
    var count: Int
    var total_words: Int
    
    fn __init__(out self):
        self.count = 0
        self.total_words = 0

fn count_words_in_file(filepath: String) raises -> Int:
    var f = open(filepath, "r")
    var content = f.read()
    f.close()
    
    var words = content.split()
    return len(words)

fn process_txt_files(path: Path, mut counter: FileCounter) raises:
    var entries = path.listdir()
    
    for i in range(len(entries)):
        var entry_name = entries[i]
        var entry_path = path / entry_name
        
        if entry_path.is_dir():
            process_txt_files(entry_path, counter)
        elif entry_path.is_file() and String(entry_name)[-4:] == ".txt":
            counter.count += 1
            var word_count = count_words_in_file(String(entry_path))
            counter.total_words += word_count
            print(counter.count, "-", entry_path, "->", word_count, "words")

fn main() raises:
    var counter = FileCounter()
    var path = Path("../gutenberg_org/")
    
    if not path.exists():
        print("Folder not found: ", path)
        return
    
    process_txt_files(path, counter)
    print("\n=== RESULTS ===")
    print("Total number of files: ", counter.count)
    print("Total number of words: ", counter.total_words)
