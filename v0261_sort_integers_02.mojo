"""
Author: Ahmet Aksoy
Date: 2026-02-23
Revision Date: 2026-02-25
Mojo version no: 0.26.1
"""

from builtin.sort import sort	# not required

fn main():
    var nums = List[Int]()
    nums.append(3)
    nums.append(1)
    nums.append(4)
    nums.append(1)
    nums.append(5)
    
    sort(nums)
    
    for i in range(len(nums)):
        print(nums[i])
