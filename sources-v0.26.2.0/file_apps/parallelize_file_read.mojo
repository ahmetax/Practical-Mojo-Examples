"""
Author: Ahmet Aksoy
Date: 2026-03-27
Mojo version: 0.26.2 | Python 3.12 | Ubuntu
"""

from std.algorithm import parallelize
from std.pathlib import Path
from std.collections import Dict

fn collect_txt_files(path: Path, mut files: List[String]) raises:
    var entries = path.listdir()
    for i in range(len(entries)):
        var entry_name = entries[i]
        var entry_path = path / entry_name
        if entry_path.is_dir():
            collect_txt_files(entry_path, files)
        elif entry_path.is_file():
            # if entry_name.suffix() == ".txt":
            if entry_name.name()[byte=-4:] == ".txt":
                files.append(String(entry_path))

fn save_file_list(files: List[String]) raises:
    """Save file list to disk."""
    var f = open("file_list.txt", "w")
    for i in range(len(files)):
        f.write(files[i] + "\n")
    f.close()

fn load_file_at_index_safe(index: Int) -> String:
    """Read a file for a given index."""
    try:
        var f = open("file_list.txt", "r")
        var content = f.read()
        f.close()
        
        var lines = content.split("\n")
        return String(lines[index])
    except:
        return String("")

fn main() raises:
    # 1. Collect the files in a list and save it to a file
    var files = List[String]()
    var path = Path("/home/axax/github/Practical-Mojo-Examples/gutenberg_org/")
    # var path = Path("../gutenberg_org/gutenberg_org/")
    
    print("Collecting files...")
    collect_txt_files(path, files)
    print("Total number of files:", len(files))
    
    save_file_list(files)
    print("File List Saved")
    
    # 2. Test: Process first 10 files in parallel
    @parameter
    fn worker(file_idx: Int):
        var filepath = load_file_at_index_safe(file_idx)
        if len(filepath) > 0:
            print("Working:", filepath)
    
    print("\nParallel processing started...")
    parallelize[worker](min(10, len(files)), num_workers=4)
    print("Finished!")
 