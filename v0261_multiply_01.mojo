fn multiply_fast(a: Int, b: Int) -> Int:
    return a * b  # Compiled, optimized, rocket-fast

def multiply_python(a:Int, b:Int) -> Int:
    return a * b  # Good old Python flexibility

fn main() raises:
    print("Fast:", multiply_fast(6, 7))
    print("Flexible:", multiply_python(6, 7))