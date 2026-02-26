from math import factorial, sqrt

# Use Gregory-Leibniz Series -> PI = 4*(1-1/3+1/5-1/7+1/9...)
fn gl_pi(n: UInt) -> Float64:
    var pi: Float64 = 0
 
    for i in range(n):
        if i % 2 == 0:
            pi += 1.0/(2.0*Float64(i)+1.0)
        else:
            pi -= 1.0/(2.0*Float64(i)+1.0)
    return pi * 4.0

fn main() raises:    
    print(gl_pi(1_000_000))

