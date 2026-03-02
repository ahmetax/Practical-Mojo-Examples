"""
Author: Ahmet Aksoy
Date: 2026-02-25
Revision Date: 2026-03-01
Mojo version no: 0.26.1
"""

from algorithm import parallelize
from pathlib import Path
from collections import Dict
from time import perf_counter_ns

fn tr_lower(word: String) -> String:
    var nword = word.replace("İ", "i").replace("I", "ı")
    return nword.lower()

fn collect_txt_files(path: Path, mut files: List[String]) raises:
    var entries = path.listdir()
    
    for i in range(len(entries)):
        var entry_name = entries[i]
        var entry_path = path / entry_name
        
        if entry_path.is_dir():
            collect_txt_files(entry_path, files)
        elif entry_path.is_file() and String(entry_name)[-4:] == ".txt":
            files.append(String(entry_path))

fn extract_turkish_body(mut text: String) -> String:
    var start_marker = "*** START OF TURKISH PART ***\n"
    var end_marker = "*** END OF TURKISH PART ***\n"
    
    var start = text.find(start_marker)
    var end = text.find(end_marker)
    
    if start == -1 or end == -1:
        return text
    
    start = start + len(start_marker)
    return String(text[start:end])

fn process_and_save_single_file(filepath: String, worker_id: Int) -> Bool:
    """Dosyayı işle ve sonuçları geçici dosyaya ekle."""
    try:
        var f = open(filepath, "r")
        var content = f.read()
        f.close()
        
        var turkish_text = extract_turkish_body(content)
        
        # Noktalama temizle
        for punct in ['.', ',', '!', '?', ';', ':', '"', '(', ')']:
            turkish_text = turkish_text.replace(punct, ' ')
        turkish_text = turkish_text.replace("'", "")
        
        # Ekstra karakterler
        for char in ['-', '_', '*', '|', '+', '%', '[', ']', '{', '}', '/', '\\', '=']:
            turkish_text = turkish_text.replace(char, ' ')
        
        var words = turkish_text.split()
        var word_freq = Dict[String, Int]()
        
        for i in range(len(words)):
            var word = tr_lower(String(words[i]))
            if len(word) >= 2:
                word_freq[word] = word_freq.get(word, 0) + 1
        
        # Sonuçları dosyaya yaz (append mode)
        var out_file = open("temp_worker_" + String(worker_id) + ".txt", "a")
        for item in word_freq.items():
            out_file.write(item.key + ":" + String(item.value) + "\n")
        out_file.close()
        
        return True
    except:
        return False

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

fn merge_temp_files(num_workers: Int) raises -> Dict[String, Int]:
    """Geçici dosyaları oku ve birleştir."""
    var final_dict = Dict[String, Int]()
    
    for w in range(num_workers):
        var filename = "temp_worker_" + String(w) + ".txt"
        print("Birleştiriliyor:", filename)
        
        try:
            var f = open(filename, "r")
            var content = f.read()
            f.close()
            
            var lines = content.split("\n")
            for i in range(len(lines)):
                var line = String(lines[i])
                if len(line) > 0:
                    var parts = line.split(":")
                    if len(parts) == 2:
                        var word = String(parts[0])
                        var count = Int(String(parts[1]))
                        final_dict[word] = final_dict.get(word, 0) + count
        except:
            print("Hata:", filename)
    
    return final_dict^

fn split_file_list(files: List[String], num_workers: Int) raises:
    """Dosya listesini worker sayısı kadar dosyaya böl."""
    var files_per_worker = len(files) // num_workers
    
    for w in range(num_workers):
        var start_idx = w * files_per_worker
        var end_idx = start_idx + files_per_worker
        
        if w == num_workers - 1:
            end_idx = len(files)
        
        var f = open("file_list_worker_" + String(w) + ".txt", "w")
        for i in range(start_idx, end_idx):
            f.write(files[i] + "\n")
        f.close()
        print("Worker", w, "için", end_idx - start_idx, "dosya kaydedildi")

fn load_file_for_worker(worker_id: Int, index: Int) -> String:
    """Belirli worker'ın dosya listesinden oku."""
    try:
        var f = open("file_list_worker_" + String(worker_id) + ".txt", "r")
        var content = f.read()
        f.close()
        
        var lines = content.split("\n")
        if index < len(lines):
            return String(lines[index])
        return String("")
    except:
        return String("")

fn main() raises:
    var files = List[String]()
    var path = Path("./gutenberg_turkish/")
    
    print("Dosyalar toplanıyor...")
    collect_txt_files(path, files)
    print("Toplam dosya:", len(files))
    
    var num_workers = 4
    # var files_per_worker = len(files) // num_workers
    
    # Dosya listelerini böl
    split_file_list(files, num_workers)
    
    # Geçici dosyaları temizle
    for w in range(num_workers):
        try:
            var temp_f = open("temp_worker_" + String(w) + ".txt", "w")
            temp_f.close()
        except:
            pass
    
    print("\nParalel işleme başlıyor...")
    var t_start = perf_counter_ns()
    
    @parameter
    fn worker(batch_id: Int):
        # Dosya listesini bir kez oku
        var my_files = List[String]()
        try:
            var f = open("file_list_worker_" + String(batch_id) + ".txt", "r")
            var content = f.read()
            f.close()
            var lines = content.split("\n")
            for i in range(len(lines)):
                if len(lines[i]) > 0:
                    my_files.append(String(lines[i]))
        except:
            return
        
        # Bellekteki Dict'i kullan
        var word_freq = Dict[String, Int]()
        
        for local_idx in range(len(my_files)):
            var filepath = my_files[local_idx]
            
            # Dosyayı işle VE Dict'e ekle (dosyaya yazmadan)
            try:
                var f = open(filepath, "r")
                var content = f.read()
                f.close()
                
                var turkish_text = extract_turkish_body(content)

                # ... noktalama temizliği ...
                for punct in ['.', ',', '!', '?', ';', ':', '"', '(', ')']:
                    turkish_text = turkish_text.replace(punct, ' ')
                turkish_text = turkish_text.replace("'", "")
                
                # Ekstra karakterler
                for char in ['-', '_', '*', '|', '+', '%', '[', ']', '{', '}', '/', '\\', '=']:
                    turkish_text = turkish_text.replace(char, ' ')
                
                var words = turkish_text.split()
                for i in range(len(words)):
                    var word = tr_lower(String(words[i]))
                    if len(word) >= 2:
                        word_freq[word] = word_freq.get(word, 0) + 1
            except:
                pass
            
            if local_idx % 1000 == 0:
                print("Worker", batch_id, "- İşlendi:", local_idx, "/", len(my_files))
        
        # Sonunda Dict'i TOPLU olarak dosyaya yaz
        try:
            var out_f = open("temp_worker_" + String(batch_id) + ".txt", "w")
            for item in word_freq.items():
                out_f.write(item.key + ":" + String(item.value) + "\n")
            out_f.close()
        except:
            pass

    parallelize[worker](num_workers, num_workers=num_workers)
    var t_process = perf_counter_ns()
    
    print("\nSonuçlar birleştiriliyor...")
    var final_dict = merge_temp_files(num_workers)
    var t_end = perf_counter_ns()
    
    print("\n=== SONUÇLAR ===")
    print("Toplam benzersiz kelime:", len(final_dict))
    print("İşleme süresi:", (t_process - t_start) // 1_000_000_000, "saniye")
    print("Birleştirme süresi:", (t_end - t_process) // 1_000_000_000, "saniye")
    print("TOPLAM:", (t_end - t_start) // 1_000_000_000, "saniye")

