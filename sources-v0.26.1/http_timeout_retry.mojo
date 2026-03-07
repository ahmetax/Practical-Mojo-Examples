"""
Author: Ahmet Aksoy
Date: 2026-03-06
Revision Date: 2026-03-06
Mojo version no: 0.26.1
AI: Claude Sonnet 4.6

Description:
    Handling timeouts and automatic retries for HTTP requests in Mojo.
    Network requests can fail for many reasons: slow servers, dropped
    connections, temporary outages. This example shows how to write
    robust request code that recovers gracefully from such failures.

    Three patterns are demonstrated:
      1. Timeout control      — don't wait forever for a response
      2. Manual retry loop    — retry failed requests with a delay
      3. Retry with backoff   — increase wait time between each retry
                                to avoid hammering a struggling server

    For testing, we use https://httpbin.org which provides endpoints
    that simulate delays and errors on demand:
      /delay/{n}         — waits n seconds before responding
      /status/{code}     — returns the given HTTP status code

Requirements:
    pip install requests
"""

from python import Python

def request_with_timeout(url: String, timeout_seconds: Int) -> None:
    """
    A timeout prevents your program from hanging indefinitely.
    requests accepts two timeout values as a tuple:
      (connect_timeout, read_timeout)
    connect_timeout: max seconds to establish the connection
    read_timeout:    max seconds to wait for the server to send data.

    If you pass a single value, it applies to both.
    """
    requests = Python.import_module("requests")

    # Build a (connect, read) timeout tuple via Python.evaluate()
    # connect: 3s to establish connection, read: timeout_seconds to receive data
    var timeout = Python.evaluate("lambda c, r: (c, r)")(3, timeout_seconds)

    try:
        print("Requesting:", url)
        print("Timeout set to: 3s connect,", timeout_seconds, "s read")
        response = requests.get(url, timeout=timeout)
        print("Response received! Status:", response.status_code)

    except:
        # Note: Mojo does not yet support 'except Exception as e' syntax.
        # We cannot inspect the exception type at runtime.
        # In practice, for this URL and timeout setting, the likely cause
        # is a read timeout — the server took longer than timeout_seconds.
        print("Request failed — likely timed out or connection error.")


def request_with_manual_retry(url: String, max_retries: Int) -> None:
    """
    Retry the request up to max_retries times if it fails.
    This is useful for transient errors (e.g. 503 Service Unavailable)
    where retrying after a short wait often succeeds.
    """
    requests = Python.import_module("requests")
    time      = Python.import_module("time")

    var attempt  = 0
    var delay    = 2  # seconds to wait between retries

    while attempt < max_retries:
        attempt += 1
        print("Attempt", attempt, "of", max_retries, "->", url)

        try:
            response = requests.get(url, timeout=10)

            if response.status_code == 200:
                print("Success on attempt", attempt, "!")
                print("Response:", String(response.text)[:80], "...")
                return
            else:
                print("  Got status", response.status_code, "— retrying in", delay, "s...")

        except:
            print("  Connection error — retrying in", delay, "s...")

        time.sleep(delay)

    print("All", max_retries, "attempts failed. Giving up.")


def request_with_backoff(url: String, max_retries: Int) -> None:
    """
    Exponential backoff: double the wait time after each failed attempt.
    This reduces load on a struggling server and improves success rate.

    Wait pattern with initial delay=1:
      Attempt 1 fails -> wait 1s
      Attempt 2 fails -> wait 2s
      Attempt 3 fails -> wait 4s
      Attempt 4 fails -> wait 8s  ...and so on
    """
    requests = Python.import_module("requests")
    time      = Python.import_module("time")

    var attempt = 0
    var delay   = 1  # initial wait in seconds

    while attempt < max_retries:
        attempt += 1
        print("Attempt", attempt, "| next backoff delay:", delay, "s ->", url)

        try:
            response = requests.get(url, timeout=10)

            if response.status_code == 200:
                print("Success on attempt", attempt, "!")
                return
            else:
                print("  Got status", response.status_code)

        except:
            print("  Connection error.")

        time.sleep(delay)
        delay *= 2  # double the wait time for next attempt

    print("All", max_retries, "attempts exhausted.")


fn main() raises:
    # Example 1: Timeout — httpbin /delay/5 waits 5 seconds before responding.
    # We set read timeout to 2s, so it should time out.
    print("=== Timeout Example ===")
    print()
    request_with_timeout("https://httpbin.org/delay/5", timeout_seconds=2)

    print()

    # Example 2: Manual retry — httpbin /status/503 always returns 503.
    # We retry 3 times with a fixed 2-second delay between attempts.
    print("=== Manual Retry Example ===")
    print()
    request_with_manual_retry("https://httpbin.org/status/503", max_retries=3)

    print()

    # Example 3: Exponential backoff — same 503 endpoint, but wait time doubles.
    # In a real scenario, replace with a URL that might temporarily fail.
    print("=== Exponential Backoff Example ===")
    print()
    request_with_backoff("https://httpbin.org/status/503", max_retries=4)
