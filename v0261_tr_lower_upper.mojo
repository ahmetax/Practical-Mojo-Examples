
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

fn main():
    var liste = ['İstanbul','Çemişkezek', 'Şanlıurfa', 'kağıthane', 'Eskişehir']
    for i in range(len(liste)):
        print(tr_lower(liste[i]))
        print(tr_upper(liste[i]))