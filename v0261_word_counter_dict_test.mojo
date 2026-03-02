"""
Author: Ahmet Aksoy
Date: 2026-02-15
Revision Date: 2026-02-25
Mojo version no: 0.26.1
"""

from pathlib import Path
from collections import Dict

fn remove_punctuation(word: String) -> String:
    # Yaygın noktalama işaretlerini replace ile temizle
    var cleaned = word
    cleaned = cleaned.replace(".", "")
    cleaned = cleaned.replace(",", "")
    cleaned = cleaned.replace("!", "")
    cleaned = cleaned.replace("?", "")
    cleaned = cleaned.replace(";", "")
    cleaned = cleaned.replace(":", "")
    cleaned = cleaned.replace("'", "")
    cleaned = cleaned.replace('"', "")
    cleaned = cleaned.replace("(", "")
    cleaned = cleaned.replace(")", "")
    
    return cleaned

fn count_word_frequencies(filepath: String) raises -> Dict[String, Int]:
    var f = open(filepath, "r")
    var content = f.read()
    f.close()
    
    var word_freq = Dict[String, Int]()
    var words = content.split()
    
    for i in range(len(words)):
        # var word = clean_word(String(words[i])).lower()
        var word = remove_punctuation(String(words[i])).lower()
        
        if len(word) == 0:  # Boş kelime atla
            continue
            
        if word in word_freq:
            word_freq[word] = word_freq[word] + 1
        else:
            word_freq[word] = 1
    
    return word_freq^

fn count_word_frequencies_old(filepath: String) raises -> Dict[String, Int]:
    var f = open(filepath, "r")
    var content = f.read()
    f.close()
    
    var word_freq = Dict[String, Int]()
    var words = content.split()
    
    for i in range(len(words)):
        var word = String(words[i]).lower()
        
        if word in word_freq:
            word_freq[word] = word_freq[word] + 1
        else:
            word_freq[word] = 1
    
    return word_freq^


fn print_top_words(word_freq: Dict[String, Int], top_n: Int) raises:
    # Dict'ten listelere çevir
    var words = List[String]()
    var counts = List[Int]()
    
    for item in word_freq.items():
        words.append(item.key)
        counts.append(item.value)
    
    # Basit sıralama (bubble sort)
    for i in range(len(counts)):
        for j in range(len(counts) - 1 - i):
            if counts[j] < counts[j + 1]:
                # Swap counts
                var temp_count = counts[j]
                counts[j] = counts[j + 1]
                counts[j + 1] = temp_count
                # Swap words
                var temp_word = words[j]
                words[j] = words[j + 1]
                words[j + 1] = temp_word
    
    print("\n=== EN SIK KULLANILAN", top_n, "KELİME ===")
    for i in range(min(top_n, len(words))):
        print(i + 1, ".", words[i], "->", counts[i], "kez")

fn main() raises:
    var frequencies = count_word_frequencies("test.txt")
    print("Toplam benzersiz kelime:", len(frequencies))
    print_top_words(frequencies, 20)
