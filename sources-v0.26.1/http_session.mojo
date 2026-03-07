"""
Author: Ahmet Aksoy
Date: 2026-03-06
Revision Date: 2026-03-06
Mojo version no: 0.26.1
AI: Claude Sonnet 4.6

Description:
    Managing HTTP sessions in Mojo using Python's requests.Session object.

    By default, each requests.get() or requests.post() call opens a new
    TCP connection to the server and closes it when done. This is fine
    for occasional requests, but inefficient when making many requests
    to the same host.

    A Session object reuses the same TCP connection (HTTP keep-alive),
    which means:
      - Faster requests — no repeated TCP handshake overhead
      - Shared headers and auth — set once, applied to every request
      - Cookie persistence — cookies returned by the server are
        automatically sent back on subsequent requests

    Three patterns are demonstrated:
      1. Basic session usage   — reusing a connection for multiple requests
      2. Session-level headers — set Authorization or User-Agent once
      3. Session with cookies  — automatic cookie handling across requests

    For testing we use https://httpbin.org which echoes back headers,
    cookies, and auth details so we can verify session state clearly.

Requirements:
    pip install requests
"""

from python import Python

def basic_session(urls: List[String]) -> None:
    """
    Open one session and send multiple GET requests through it.
    The TCP connection is reused across all requests in the list.
    Compare this to calling requests.get() separately for each URL —
    the session version avoids the overhead of reconnecting each time.
    """
    requests = Python.import_module("requests")

    # Create a session object — this opens a persistent connection pool
    session = requests.Session()

    print("Sending", len(urls), "requests through a single session...")
    print()

    for url in urls:
        try:
            response = session.get(url, timeout=10)
            print("  GET", url)
            print("  Status:", response.status_code)
        except:
            print("  Failed:", url)

    # Always close the session when done to release the connection
    session.close()
    print()
    print("Session closed.")


def session_with_headers(base_url: String, token: String) -> None:
    """
    Set headers on the session once — they are automatically included
    in every request made through that session.
    Useful for: Authorization tokens, User-Agent strings, API version headers.
    """
    requests = Python.import_module("requests")

    session = requests.Session()

    # Set headers at the session level — applied to all requests
    session.headers["Authorization"] = "Bearer " + token
    session.headers["User-Agent"]    = "MojoClient/0.26.1"
    session.headers["Accept"]        = "application/json"

    try:
        # httpbin /headers echoes back all headers it received
        response = session.get(base_url + "/headers", timeout=10)

        if response.status_code == 200:
            result   = response.json()
            received = result["headers"]
            print("Headers sent with session:")
            print("  Authorization:", String(received["Authorization"]))
            print("  User-Agent   :", String(received["User-Agent"]))
            print("  Accept       :", String(received["Accept"]))

        # A second request to a different endpoint — same headers applied
        response2 = session.get(base_url + "/get", timeout=10)
        if response2.status_code == 200:
            print()
            print("Second request also carried the same headers. Status:", response2.status_code)

    except:
        print("Error: Could not connect to the API.")

    session.close()


def session_with_cookies(base_url: String) -> None:
    """
    Sessions automatically store cookies returned by the server
    and send them back on subsequent requests — just like a browser.
    This is essential for APIs that use cookie-based authentication
    or session tokens (e.g. login flows).

    httpbin /cookies/set sets a cookie, then /cookies echoes it back.
    """
    requests = Python.import_module("requests")

    session = requests.Session()

    try:
        # Step 1: Ask httpbin to set a cookie named "session_id"
        set_url = base_url + "/cookies/set/session_id/mojo-abc-789"
        response = session.get(set_url, timeout=10)
        print("Cookie set. Status:", response.status_code)

        # Step 2: The session automatically stores the cookie.
        # Now send a second request — the cookie is sent back automatically.
        check_url = base_url + "/cookies"
        response2 = session.get(check_url, timeout=10)

        if response2.status_code == 200:
            result  = response2.json()
            cookies = result["cookies"]
            print("Cookies echoed back by server:")
            print("  session_id:", String(cookies["session_id"]))
            print()
            print("The session sent the cookie automatically — no manual handling needed.")

    except:
        print("Error: Could not connect to the API.")

    session.close()


fn main() raises:
    var base_url = "https://httpbin.org"

    # Example 1: Reuse a single session for multiple requests
    print("=== Basic Session Usage ===")
    print()
    var urls = List[String]()
    urls.append(base_url + "/get")
    urls.append(base_url + "/uuid")
    urls.append(base_url + "/ip")
    basic_session(urls)

    print()

    # Example 2: Session-level headers — set once, sent with every request
    print("=== Session with Shared Headers ===")
    print()
    session_with_headers(base_url, "my-bearer-token-xyz")

    print()

    # Example 3: Automatic cookie management across requests
    print("=== Session with Cookie Persistence ===")
    print()
    session_with_cookies(base_url)
