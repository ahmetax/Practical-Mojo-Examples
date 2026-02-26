import time

fn countdown(n: UInt) raises:
    var n_sec: UInt = n
    var n_sleep: UInt = 1
    while n_sec:
        print(n_sec)
        time.sleep(n_sleep)
        n_sec -= 1
    print("FIRE!")

fn main() raises:
    countdown(7)
