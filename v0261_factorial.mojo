fn factorial(i:UInt) -> UInt:
    if i == 0:
        return 1
    return i* factorial(i-1)
    
fn main() raises:
    print(factorial(15))