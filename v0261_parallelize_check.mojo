from algorithm import parallelize
from pathlib import Path
from collections import Dict

# Simple test - check whether parallelize works or not
fn test_parallelize() raises:
    # var counter = 0
    
    @parameter
    fn worker(i: Int):
        print("Worker works:", i)
    
    print("Parallelize test starting...")
    parallelize[worker](10, num_workers=4)
    print("Parallelize test completed!")

fn main() raises:
    test_parallelize()
