from std.gpu.host import DeviceContext
from std.sys import has_accelerator


def main() raises:
    comptime if not has_accelerator():
        print("No compatible GPU found")
    else:
        ctx = DeviceContext()
        print("Found GPU:", ctx.name())
        
