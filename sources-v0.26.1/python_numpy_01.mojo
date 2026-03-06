"""
Author: Ahmet Aksoy
Date: 2026-03-03
Revision Date: 2026-03-03
Mojo version no: 0.26.1
AI:
"""

from python import Python

fn main() raises:
    np = Python.import_module("numpy")
    array = np.array(Python.list(5, 3, 7, 4, 11))
    print(array)
    
