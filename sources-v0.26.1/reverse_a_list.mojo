"""
Author: Ahmet Aksoy
Date: 2026-02-28
Revision Date: 2026-02-28
Mojo version no: 0.26.1
"""

fn main() raises:
    var int_list = [1, 2, 3, 4, 5]
    var reversed_list = reversed(int_list)  # a new list is created
    print("Using reversed() function:")
    for el in reversed_list:
        print(el)
    
    int_list.reverse()  # original list is reversed
    print("Using list.reverse() method:")
    for el in int_list:
        print(el)
