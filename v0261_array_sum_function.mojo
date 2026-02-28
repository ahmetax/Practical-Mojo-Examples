"""
Author: Ahmet Aksoy
Date: 2026-02-28
Revision Date: 2026-02-28
Mojo version no: 0.26.1
"""
from algorithm import sum

fn main() raises:
    var a  = [1, 2, 3, 4, 5, 6, 7]

    var total = sum(a)
    print("Sum of the array using sum(): ", total)
