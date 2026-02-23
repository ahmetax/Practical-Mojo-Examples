from builtin.sort import sort

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
        return self.count > other.count  # Büyükten küçüğe
    
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

fn main():
    var items = List[WordCount]()
    items.append(WordCount("apple", 5))
    items.append(WordCount("pear", 12))
    items.append(WordCount("strawberry", 3))
    
    sort(items)
    
    for i in range(len(items)):
        print(items[i].word, "->", items[i].count)
