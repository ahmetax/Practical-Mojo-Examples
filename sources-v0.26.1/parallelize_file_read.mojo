"""
Author: Ahmet Aksoy
Date: 2026-02-26
Revision Date: 2026-03-01
Mojo version no: 0.26.1
"""

from algorithm import parallelize
from pathlib import Path
from collections import Dict

fn collect_txt_files(path: Path, mut files: List[String]) raises:
    var entries = path.listdir()
    for i in range(len(entries)):
        var entry_name = entries[i]
        var entry_path = path / entry_name
        if entry_path.is_dir():
            collect_txt_files(entry_path, files)
        elif entry_path.is_file() and String(entry_name)[-4:] == ".txt":
            files.append(String(entry_path))

fn save_file_list(files: List[String]) raises:
    """Dosya listesini diske kaydet."""
    var f = open("file_list.txt", "w")
    for i in range(len(files)):
        f.write(files[i] + "\n")
    f.close()

fn load_file_at_index_safe(index: Int) -> String:
    """Belirli satırdaki dosya yolunu oku - hata yönetimi ile."""
    try:
        var f = open("file_list.txt", "r")
        var content = f.read()
        f.close()
        
        var lines = content.split("\n")
        return String(lines[index])
    except:
        return String("")

fn main() raises:
    # 1. Dosya listesini topla ve kaydet
    var files = List[String]()
    var path = Path("../gutenberg_org/")
    
    print("Dosyalar toplanıyor...")
    collect_txt_files(path, files)
    print("Toplam dosya:", len(files))
    
    save_file_list(files)
    print("Dosya listesi kaydedildi")
    
    # 2. Test: İlk 10 dosyayı paralel işle
    @parameter
    fn worker(file_idx: Int):
        var filepath = load_file_at_index_safe(file_idx)
        if len(filepath) > 0:
            print("İşleniyor:", filepath)
    
    print("\nParalel işleme başlıyor...")
    parallelize[worker](min(10, len(files)), num_workers=4)
    print("Bitti!")
