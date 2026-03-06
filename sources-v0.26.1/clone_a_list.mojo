"""
Author: Ahmet Aksoy
Date: 2026-03-03
Revision Date: 2026-03-03
Mojo version no: 0.26.1
"""

fn main() raises:
    var my_list: List[Int] = [5, 7, 2, 3, 11, 1]
    
    var my_clone: List[Int] = my_list.copy()
    
    print("my_list : ", my_list)

    print("my_clone: ", my_clone)
    
