"""
Author: Ahmet Aksoy
Date: 2026-02-23
Revision Date: 2026-02-25
Mojo version no: 0.26.1
"""

fn main() raises:
    fn cmp_fn_desc(a: Int, b: Int) capturing -> Bool:
        return a > b

    fn cmp_fn_asc(a: Int, b: Int) capturing -> Bool:
        return a < b

    var numbers: List[Int]= [11, 3, 19, 1, 15, 4, 7]

    sort[cmp_fn_asc](numbers)
  
    print("Sorted in ascending order: ", numbers)

    sort[cmp_fn_desc](numbers)
  
    print("Sorted in descending order: ", numbers)

     
