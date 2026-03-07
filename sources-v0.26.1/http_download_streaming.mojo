"""
Author: Ahmet Aksoy
Date: 2026-03-06
Revision Date: 2026-03-06
Mojo version no: 0.26.1
AI: Claude Sonnet 4.6

Description:
    Downloading files efficiently using HTTP streaming in Mojo.

    When downloading large files, loading the entire response into memory
    at once is wasteful and can crash your program on low-memory systems.
    Streaming reads the response body in small chunks and writes each
    chunk to disk immediately, keeping memory usage flat regardless of
    file size.

    Three patterns are demonstrated:
      1. Simple download       — small files, no streaming needed
      2. Streaming download    — large files, fixed memory usage
      3. Download with progress — show how many bytes have been received

    For testing we use publicly available files from:
      https://speed.hetzner.de  — test files of various sizes
      https://httpbin.org/bytes/{n} — generates n random bytes on demand

Requirements:
    pip install requests
"""

from python import Python

def simple_download(url: String, save_path: String) -> None:
    """
    Download a small file in one shot.
    response.content loads the entire file into memory.
    Fine for small files (images, JSON, small PDFs).
    Not suitable for large files — use streaming_download() instead.
    """
    requests = Python.import_module("requests")

    try:
        print("Downloading:", url)
        response = requests.get(url, timeout=15)

        if response.status_code == 200:
            # Use Python's built-in open() for binary writing.
            # Mojo's open() does not support binary mode yet,
            # so we use Python's builtins module instead.
            builtins = Python.import_module("builtins")
            var f = builtins.open(save_path, "wb")
            f.write(response.content)
            f.close()

            var size_kb = len(response.content) // 1024
            print("Saved to:", save_path)
            print("Size    :", size_kb, "KB")
        else:
            print("Download failed. HTTP Status:", response.status_code)

    except:
        print("Error: Could not download the file.")


def streaming_download(url: String, save_path: String, chunk_size: Int) -> None:
    """
    Download a large file in chunks using stream=True.

    With stream=True, requests does not download the response body
    immediately. Instead, iter_content() yields one chunk at a time.
    Each chunk is written to disk before the next one is fetched,
    so memory usage stays constant at roughly chunk_size bytes.

    chunk_size: number of bytes per chunk. 8192 (8KB) is a common default.
    Larger chunks (e.g. 65536 = 64KB) reduce I/O overhead on fast connections.
    """
    requests = Python.import_module("requests")

    try:
        print("Streaming download:", url)
        print("Chunk size:", chunk_size // 1024, "KB")

        # stream=True tells requests to hold the connection open
        # and not load the body until we ask for it
        response = requests.get(url, stream=True, timeout=30)

        if response.status_code != 200:
            print("Download failed. HTTP Status:", response.status_code)
            return

        builtins = Python.import_module("builtins")
        var f    = builtins.open(save_path, "wb")
        var total_bytes = 0
        var chunk_count = 0

        # iter_content yields raw bytes chunks
        for chunk in response.iter_content(chunk_size=chunk_size):
            # iter_content may yield empty chunks — skip them
            if chunk:
                f.write(chunk)
                total_bytes += len(chunk)
                chunk_count += 1

        f.close()

        print("Download complete!")
        print("  Saved to   :", save_path)
        print("  Total size :", total_bytes // 1024, "KB")
        print("  Chunks read:", chunk_count)

    except:
        print("Error: Streaming download failed.")


def streaming_download_with_progress(url: String, save_path: String) -> None:
    """
    Streaming download with a simple progress indicator.
    Reads Content-Length header to calculate percentage if available.
    Some servers do not send Content-Length — in that case we show
    only the bytes received so far.
    """
    requests = Python.import_module("requests")

    var chunk_size = 8192

    try:
        print("Downloading with progress:", url)

        response = requests.get(url, stream=True, timeout=30)

        if response.status_code != 200:
            print("Download failed. HTTP Status:", response.status_code)
            return

        # Try to read Content-Length header for progress calculation
        var total_size  = 0
        var has_length  = False
        # Use Python.none() to represent Python's None value.
        # Python.None (attribute) does not exist in Mojo — use Python.none() instead.
        content_length = response.headers.get("Content-Length", Python.none())

        if content_length != Python.none():
            total_size = Int(String(content_length))
            has_length = True
            print("File size:", total_size // 1024, "KB")
        else:
            print("File size: unknown (no Content-Length header)")

        builtins     = Python.import_module("builtins")
        var f        = builtins.open(save_path, "wb")
        var received      = 0
        var last_reported = 0  # track last printed progress step

        for chunk in response.iter_content(chunk_size=chunk_size):
            if chunk:
                f.write(chunk)
                received += len(chunk)

                if has_length:
                    var percent = (received * 100) // total_size
                    # Print progress every 10%
                    if percent >= last_reported + 10:
                        last_reported = (percent // 10) * 10
                        print("  Progress:", last_reported, "%  (", received // 1024, "KB )")
                else:
                    # No Content-Length — just report every 50KB
                    if received - last_reported >= 50 * 1024:
                        last_reported = received
                        print("  Received:", received // 1024, "KB")

        f.close()
        print("Download complete! Saved to:", save_path)
        print("Total received:", received // 1024, "KB")

    except:
        print("Error: Download with progress failed.")


fn main() raises:
    # Example 1: Simple download — httpbin generates 10KB of random bytes
    print("=== Simple Download ===")
    print()
    simple_download(
        "https://httpbin.org/bytes/10240",
        "/tmp/simple_download.bin"
    )

    print()

    # Example 2: Streaming download — httpbin generates 1MB of random bytes
    # chunk_size = 8192 bytes (8KB per chunk)
    print("=== Streaming Download ===")
    print()
    streaming_download(
        "https://httpbin.org/bytes/1048576",
        "/tmp/streaming_download.bin",
        8192
    )

    print()

    # Example 3: Streaming with progress — 500KB file
    print("=== Streaming Download with Progress ===")
    print()
    streaming_download_with_progress(
        "https://httpbin.org/bytes/512000",
        "/tmp/progress_download.bin"
    )
