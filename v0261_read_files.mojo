from pathlib import Path

struct FileCounter:
    var count: Int
    
    fn __init__(out self):
        self.count = 0
    
    fn increment(mut self):
        self.count += 1

# reads a file giving its path as a string
fn read_file(filepath: String) raises:
    # Dosyayı aç ve oku
    var f = open(filepath, "r")
    var content = f.read()
    f.close()
    print(content)

# reads a file giving its Path
fn read_txt_file(path: Path) raises -> String:
    var f = open(String(path), "r")
    var content: String = f.read()
    f.close()
    return content

fn read_lines(filepath: String) raises -> List[String]:
    var f = open(filepath, "r")
    var content = f.read()
    f.close()
    var lines = [String(x) for x in content.split("\n")]
    
    return lines^   # transfer ownership


fn find_txt_recursive(path: Path, mut counter: FileCounter) raises:
    var entries = path.listdir()
    
    for i in range(len(entries)):
        var entry_name = entries[i]
        var entry_path = path / entry_name
        
        if entry_path.is_dir():
            find_txt_recursive(entry_path, counter)
        elif entry_path.is_file() and String(entry_name)[-4:] == ".txt":
            counter.increment()
            print(counter.count, "-", entry_path)
            # print some text

            # var text:String = read_txt_file(entry_path)
            # print(text)

            # read lines
            var lines = read_lines(String(entry_path))
            for line in lines:
                print(line)

            if counter.count > 4:   # process only 5 files
                break

fn find_txt_files(directory: String) raises:
    var path = Path(directory)
    
    if not path.exists():
        print("Folder not found:", directory)
        return
    
    var counter = FileCounter()
    find_txt_recursive(path, counter)
    print("\nToplam", counter.count, ".txt file found.")

fn main() raises:
    my_folder:String ="./gutenberg_org/"
    # give the folder tame
    find_txt_files(my_folder)
    
