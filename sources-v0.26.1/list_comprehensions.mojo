fn main() raises:
    # list of squares in range 0-10
    var list: List[UInt64] = [x*x for x in range(11)]
    print(list)
    print()
    var list2 = [1, 2, 4, 7, 9, 10, 12, 15]
    # list of even numbers 
    var list3 = [UInt(x) for x in list2 if x%2==0]
    print(list3)
