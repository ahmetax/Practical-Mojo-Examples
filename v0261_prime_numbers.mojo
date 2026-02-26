
fn main() raises:
    var lownum: UInt = 0
    var highnum:UInt = 127
    
    for n in range(lownum, highnum + 1):
        if n > 1:
            for i in range(2, n):
                if n % i == 0:
                    break
            else:
                print(n)
                    
