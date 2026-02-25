from python import Python

fn main() raises:
    
    var time = Python.import_module("time")

    var t0 = time.time()
    var sum = 0
    for i in range(1000_000):
        sum += i
    print('Sum : ', sum)
    var t1 = time.time()
    
    print("Start:", t0)
    print("End : :", t1)
    print("Difference", (t1-t0), "seconds")