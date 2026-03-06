"""
Author: Ahmet Aksoy
Date: 2026-03-05
Revision Date: 2026-03-05
Mojo version no: 0.26.1
AI: Claude

Description:
    Fetching data from a public JSON API using Python's requests module.
    This example uses the JSONPlaceholder API (https://jsonplaceholder.typicode.com)
    which is a free, public REST API for testing and prototyping.

    We fetch a list of posts, filter them by user ID, and display
    selected fields. This pattern is directly applicable to any
    REST API that returns JSON data.

Requirements:
    pip install requests
"""

from python import Python
from collections import Dict

def fetch_posts(user_id: Int) -> None:
    requests = Python.import_module("requests")
    json = Python.import_module("json")

    var url = "https://jsonplaceholder.typicode.com/posts"

    # Build query parameters as a Python dict
    params = Python.dict()
    params["userId"] = user_id

    try:
        response = requests.get(url, params=params, timeout=10)

        # Check HTTP status code before processing
        if response.status_code != 200:
            print("Request failed. HTTP Status:", response.status_code)
            return

        posts = response.json()
        var count = len(posts)
        print("Found", count, "posts for user ID:", user_id)
        print("----------------------------------------------")

        for post in posts:
            var post_id    = String(post["id"])
            var title      = String(post["title"])
            var body_preview = String(post["body"])[:60]  # First 60 chars
            print("Post #" + post_id)
            print("  Title  :", title)
            print("  Preview:", body_preview + "...")
            print()

    except:
        print("Error: Could not connect to the API.")
        print("Check your internet connection and try again.")


def fetch_single_post(post_id: Int) -> None:
    requests = Python.import_module("requests")

    var url = "https://jsonplaceholder.typicode.com/posts/" + String(post_id)

    try:
        response = requests.get(url, timeout=10)

        if response.status_code == 404:
            print("Post not found. ID:", post_id)
            return

        if response.status_code != 200:
            print("Request failed. HTTP Status:", response.status_code)
            return

        post = response.json()

        print("Post details")
        print("----------------------------------------------")
        print("  ID    :", String(post["id"]))
        print("  UserID:", String(post["userId"]))
        print("  Title :", String(post["title"]))
        print("  Body  :")
        print(String(post["body"]))

    except:
        print("Error: Could not connect to the API.")


fn main() raises:
    # Example 1: Fetch all posts by a specific user
    print("=== Fetching posts for user ID: 2 ===")
    print()
    fetch_posts(2)

    # Example 2: Fetch a single post by its ID
    print()
    print("=== Fetching single post with ID: 7 ===")
    print()
    fetch_single_post(7)
