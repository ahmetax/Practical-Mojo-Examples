"""
Author: Ahmet Aksoy
Date: 2026-03-04
Revision Date: 2026-03-05
Mojo version no: 0.26.1
"""

from python import Python
from collections import Dict

def summarize_text(text:String, percent:Float64, lang:String='en', DETAIL:Bool=False) -> String:
    # load spacy model
    spacy = Python.import_module('spacy')
    # var WORDS = Python.none()
    if lang=='tr':
        nlp = spacy.load("tr_core_news_trf")
        WORDS = spacy.lang.tr.stop_words.STOP_WORDS
    else:
        nlp = spacy.load('en_core_web_sm')
        WORDS = spacy.lang.en.stop_words.STOP_WORDS
    
    nltk = Python.import_module('nltk')
    nlargest = Python.import_module('heapq').nlargest
    punctuation = Python.import_module('string').punctuation

    # separate text into tokens using spacy model
    doc = nlp(text)
    if DETAIL:
        print(); print('-------------------------')
        print("TOKENS")
        n=0
        for token in doc:
            n += 1
            if n > 10: break
            # token text and part-of-speech tag
            print(token.text, "-->", token.pos_)

    # convert tokens to text
    tokens=[token.text for token in doc]
    if DETAIL:
        print(); print('-------------------------')
        print("TOKEN.TEXT LIST")
        for i in range(10):
            print(tokens[i])

    # find word frequencies
    word_freq = Dict[String, Float64]()
    var wmax = 0
    # var tmax = ""
    for word in doc:
        var wtext = String(word.text)
        # Düzeltme: Python nesnesi olan WORDS için .__contains__() kullan
        if not WORDS.__contains__(wtext.lower()):
            if not punctuation.__contains__(wtext.lower()):
                if wtext in word_freq:
                    word_freq[wtext] += 1
                    if word_freq[wtext] > wmax:
                        wmax = Int(word_freq[wtext])
                        # tmax = wtext
                else:
                    word_freq[wtext] = 1
                    if word_freq[wtext] > wmax:
                        wmax = Int(word_freq[wtext])
                        # tmax = wtext                    
    # Bulunan en yüksek frekans
    max_frequency = wmax
    if DETAIL:
        print(); print('-------------------------')
        print("max_frequency= ", max_frequency)

    # normalize frequency values
    py_word_freq = Python.dict()
    for item in word_freq.items():
        py_word_freq[item.key] = item.value / max_frequency
    # create sentence tokens
    sentence_tokens= [String(sent) for sent in doc.sents]

    # Calculate sentence scores
    sentence_scores = Dict[String, Float64]()
    for sent in sentence_tokens:
        for word in sent.split():
            var wtext = String(word).lower()
            if wtext in word_freq:
                if sent in sentence_scores:                            
                    sentence_scores[sent] += word_freq[wtext]
                else:
                    sentence_scores[sent] = word_freq[wtext]

    # Düzeltme: sentence_scores'u Python dict'ine çevir, nlargest'e Python callable ver
    py_sentence_scores = Python.dict()
    for item in sentence_scores.items():
        py_sentence_scores[item.key] = item.value

    # Separate the percentile of the sentences with the highest scores.
    var select_length = Int(len(sentence_tokens) * percent)
    # Python evaluate ile lambda oluştur
    var get_score = Python.evaluate("lambda scores: lambda k: scores[k]")
    summary = nlargest(select_length, py_sentence_scores.keys(), key=get_score(py_sentence_scores))

    # Combine the sentences with the highest scores.
    # Düzeltme: .text yerine str() kullan, summary Python string listesidir
    final_summary = [String(word) for word in summary]
    var result = String(' '.join(final_summary))
    return result

fn main() raises:
    # Düzeltme: var ile tanımla
    var lang = 'en'
    var DETAIL = False
    var percent: Float64 = 0.1

    var rtext: String
    if lang == 'tr':
        var f = open("alice_tr.txt", "r")
        var fulltext = f.read()
        f.close()
        rtext = summarize_text(fulltext, percent, lang='tr', DETAIL=DETAIL)
    else:
        var f = open("alice_en.txt", "r")
        var fulltext = f.read()
        f.close()
        rtext = summarize_text(fulltext, percent, lang='en', DETAIL=DETAIL)

    print(); print('-----------------------------')
    print("RESULT - 10% SUMMARY")
    print(rtext)
