"""
Author: Ahmet Aksoy
Date: 2026-03-07
Revision Date: 2026-03-07
Mojo version no: 0.26.1
AI: Claude Sonnet 4.6

Description:
    Collecting system information in Mojo using Python's os, platform,
    and psutil modules with explicit PythonObject typing (Style B).

    Four categories of information are collected:
      1. OS and kernel   — operating system, hostname, kernel version
      2. CPU             — core count, frequency, usage percentage
      3. Memory          — total, available, used, percentage
      4. Disk            — total, used, free space per partition

    This pattern is useful for:
      - System monitoring scripts
      - Logging environment info at program startup
      - Generating diagnostic reports

    os and platform are part of Python's standard library.
    psutil requires installation:

Requirements:
    pip install psutil
"""

from python import Python, PythonObject


fn collect_os_info() raises -> None:
    """
    Collect basic OS and hostname information using
    Python's os and platform modules.
    Both are standard library — no installation needed.
    """
    os: PythonObject       = Python.import_module("os")
    platform: PythonObject = Python.import_module("platform")

    var system:   String = String(platform.system())
    var node:     String = String(platform.node())
    var release:  String = String(platform.release())
    var version:  String = String(platform.version())
    var machine:  String = String(platform.machine())
    var processor:String = String(platform.processor())
    var py_ver:   String = String(platform.python_version())

    print("  OS        :", system)
    print("  Hostname  :", node)
    print("  Release   :", release)
    print("  Version   :", version)
    print("  Machine   :", machine)
    print("  Processor :", processor)
    print("  Python    :", py_ver)
    print("  PID       :", String(os.getpid()))


fn collect_cpu_info() raises -> None:
    """
    Collect CPU information using psutil.
    cpu_count()       — number of logical cores
    cpu_freq()        — current, min, max frequency in MHz
    cpu_percent()     — usage over a 1-second interval
    cpu_times()       — time spent in user, system, idle modes.
    """
    psutil: PythonObject = Python.import_module("psutil")

    var logical:  Int    = Int(Float64(String(psutil.cpu_count(logical=True))))
    var physical: Int    = Int(Float64(String(psutil.cpu_count(logical=False))))

    # cpu_freq() returns a named tuple: current, min, max (in MHz)
    freq: PythonObject   = psutil.cpu_freq()
    var freq_current: Float64 = Float64(String(freq.current))
    var freq_min: Float64     = Float64(String(freq.min))
    var freq_max: Float64     = Float64(String(freq.max))

    # cpu_percent(interval=1) blocks for 1 second then returns usage %
    var usage: Float64 = Float64(String(psutil.cpu_percent(interval=1)))

    # cpu_times() — cumulative time in seconds per mode
    times: PythonObject  = psutil.cpu_times()
    var user_time: Float64   = Float64(String(times.user))
    var system_time: Float64 = Float64(String(times.system))
    var idle_time: Float64   = Float64(String(times.idle))

    print("  Logical cores :", logical)
    print("  Physical cores:", physical)
    print("  Frequency     : current =", freq_current, "MHz  min =",
          freq_min, "MHz  max =", freq_max, "MHz")
    print("  CPU usage     :", usage, "%  (measured over 1 second)")
    print("  CPU times     : user =", user_time, "s  system =",
          system_time, "s  idle =", idle_time, "s")


fn collect_memory_info() raises -> None:
    """
    Collect RAM usage using psutil.virtual_memory().
    Returns total, available, used, and percentage used.
    All byte values are converted to MB for readability.
    """
    psutil: PythonObject = Python.import_module("psutil")

    mem: PythonObject = psutil.virtual_memory()

    # Values are in bytes — divide by 1024^2 for MB
    var total:     Float64 = Float64(String(mem.total))     / 1048576.0
    var available: Float64 = Float64(String(mem.available)) / 1048576.0
    var used:      Float64 = Float64(String(mem.used))      / 1048576.0
    var percent:   Float64 = Float64(String(mem.percent))

    print("  Total    :", total, "MB")
    print("  Used     :", used, "MB")
    print("  Available:", available, "MB")
    print("  Usage    :", percent, "%")

    # Swap memory
    swap: PythonObject = psutil.swap_memory()
    var swap_total:   Float64 = Float64(String(swap.total))   / 1048576.0
    var swap_used:    Float64 = Float64(String(swap.used))    / 1048576.0
    var swap_percent: Float64 = Float64(String(swap.percent))

    print("  Swap total:", swap_total, "MB  used:", swap_used,
          "MB  (", swap_percent, "%)")


fn collect_disk_info() raises -> None:
    """
    Collect disk partition and usage info using psutil.
    disk_partitions() lists all mounted filesystems.
    disk_usage(path) returns total, used, free for a given mount point.
    """
    psutil: PythonObject = Python.import_module("psutil")

    partitions: PythonObject = psutil.disk_partitions()
    var count: Int = Int(Float64(String(len(partitions))))

    print("  Found", count, "partition(s):")
    print()

    for i in range(count):
        var part: PythonObject = partitions[i]
        var device:     String = String(part.device)
        var mountpoint: String = String(part.mountpoint)
        var fstype:     String = String(part.fstype)

        print("  Partition :", device)
        print("  Mount     :", mountpoint)
        print("  Filesystem:", fstype)

        # disk_usage() can fail on some special mounts (e.g. /dev)
        try:
            usage: PythonObject = psutil.disk_usage(mountpoint)
            var total: Float64 = Float64(String(usage.total)) / 1073741824.0
            var used:  Float64 = Float64(String(usage.used))  / 1073741824.0
            var free:  Float64 = Float64(String(usage.free))  / 1073741824.0
            var pct:   Float64 = Float64(String(usage.percent))
            print("  Total     :", total, "GB")
            print("  Used      :", used,  "GB  (", pct, "%)")
            print("  Free      :", free,  "GB")
        except:
            print("  Usage     : not available for this mount")

        print()


fn main() raises:
    print("=== OS and Kernel Info ===")
    print()
    collect_os_info()

    print()
    print("=== CPU Info ===")
    print()
    collect_cpu_info()

    print()
    print("=== Memory Info ===")
    print()
    collect_memory_info()

    print()
    print("=== Disk Info ===")
    print()
    collect_disk_info()
