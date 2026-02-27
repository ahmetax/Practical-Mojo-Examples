"""
Author: Ahmet Aksoy
Date: 2026-02-27
Revision Date: 2026-02-27
Mojo version no: 0.26.1
"""

# Armstrong number -> abcd... = pow(a,n) + pow(b,n) + pow(c,n) + pow(d,n) + ....

fn is_armstrong(n: Int) -> Bool:
    var nums = String(n)
    var digits = len(nums)
    var sum = 0

    for digit_char in nums.codepoints():
        var d = Int(digit_char) - 48    # convert to integer value of the digit
        sum += d ** digits

    return sum == n

fn main() raises:
    for number in range(0, 100000):
        if is_armstrong(number):
            print(number)
       
