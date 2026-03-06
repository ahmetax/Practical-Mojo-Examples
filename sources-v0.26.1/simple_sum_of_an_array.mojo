"""
Author: Ahmet Aksoy
Date: 2026-03-03
Revision Date: 2026-03-05
Mojo version no: 0.26.1
AI:
"""

fn main() raises:
    # SIMD = Single Instruction, Multiple Data
    var arr = SIMD[DType.int8, 5](6, 1, 17, 3, 11);  # it is very fast
    
    var total = 0
    for i in range(len(arr)):
        total += Int(arr[i])
    
    print("arr: ", arr)
    print("total: ", total)
    
    
