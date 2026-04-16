"""
Author: Ahmet Aksoy
Date: 2026-04-11
Mojo version no: 0.26.2 Python-3.2 Ubuntu-24.04
"""

fn factorial(i:UInt) -> UInt:
    if i == 0:
        return 1
    return i* factorial(i-1)
    
fn main() raises:
    print(factorial(15))
