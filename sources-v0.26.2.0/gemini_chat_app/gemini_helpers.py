"""
Gemini Chat App Flask route handler.
Uses Google AI Studio API (OpenAI-compatible endpoint) with streaming.
Supports web search (Tavily) and crypto price (CoinGecko) tool calling.
"""

import json
import os
import requests
from flask import render_template, request, Response, stream_with_context


# ------------------------------------------------------------------ #
# Load .env
# ------------------------------------------------------------------ #

def _load_env():
    env_path = os.path.join(os.path.dirname(__file__), '.env')
    if os.path.exists(env_path):
        with open(env_path) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, val = line.split('=', 1)
                    os.environ.setdefault(key.strip(), val.strip())

_load_env()

GEMINI_KEY  = os.environ.get("GEMINI_API_KEY", "")
TAVILY_KEY  = os.environ.get("TAVILY_API_KEY", "")
GEMINI_BASE = "https://generativelanguage.googleapis.com/v1beta"

AVAILABLE_MODELS = [
    "gemini-2.5-flash",            # recommended — free tier, stable
    "gemini-2.5-flash-preview-04-17",
    "gemini-2.5-pro-preview-05-06",
    "gemini-2.0-flash-lite",
    "gemini-1.5-flash-latest",
]

if not GEMINI_KEY:
    print("Warning: GEMINI_API_KEY not set. Add it to .env file.")


# ------------------------------------------------------------------ #
# Tool definitions (OpenAI format)
# ------------------------------------------------------------------ #

TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "web_search",
            "description": (
                "Search the web for current information, news, or recent events. "
                "Use this when asked about anything that may have changed recently."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "The search query."
                    }
                },
                "required": ["query"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "get_crypto_price",
            "description": (
                "Get the current real-time price and market data for a cryptocurrency."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "coin": {
                        "type": "string",
                        "description": "Coin name or symbol. Examples: bitcoin, ethereum, BTC"
                    }
                },
                "required": ["coin"]
            }
        }
    }
]


# ------------------------------------------------------------------ #
# Tavily web search
# ------------------------------------------------------------------ #

def web_search(query, max_results=5):
    """Search the web using Tavily API."""
    results = []
    try:
        res = requests.post(
            "https://api.tavily.com/search",
            json={
                "api_key"            : TAVILY_KEY,
                "query"              : query,
                "max_results"        : max_results,
                "search_depth"       : "basic",
                "include_answer"     : True,
                "include_raw_content": False,
            },
            timeout=15
        )
        data = res.json()
        if data.get("answer"):
            results.append({
                "title"  : "Direct Answer",
                "url"    : "",
                "snippet": data["answer"]
            })
        for r in data.get("results", []):
            results.append({
                "title"  : r.get("title", ""),
                "url"    : r.get("href", r.get("url", "")),
                "snippet": r.get("content", "")
            })
    except Exception as e:
        results.append({"title": "Search error", "url": "", "snippet": str(e)})
    return results


def format_search_results(query, results):
    """Format search results as readable string for the model."""
    if not results:
        return "No results found for: " + query
    lines = ["Web search results for: '" + query + "'\n"]
    for i, r in enumerate(results, 1):
        lines.append(str(i) + ". " + r["title"])
        if r["url"]:
            lines.append("   URL: " + r["url"])
        lines.append("   " + r["snippet"])
        lines.append("")
    return "\n".join(lines)


# ------------------------------------------------------------------ #
# CoinGecko crypto prices
# ------------------------------------------------------------------ #

COIN_ID_MAP = {
    "btc": "bitcoin", "eth": "ethereum", "sol": "solana",
    "bnb": "binancecoin", "xrp": "ripple", "ada": "cardano",
    "doge": "dogecoin", "dot": "polkadot", "ltc": "litecoin",
    "avax": "avalanche-2", "link": "chainlink", "uni": "uniswap",
}


def get_crypto_price(coin):
    """Fetch real-time crypto price from CoinGecko API."""
    coin_id = COIN_ID_MAP.get(coin.lower().strip(), coin.lower().strip())
    try:
        res = requests.get(
            "https://api.coingecko.com/api/v3/coins/" + coin_id,
            params={"localization": "false", "tickers": "false",
                    "community_data": "false", "developer_data": "false"},
            timeout=10,
            headers={"User-Agent": "Mozilla/5.0"}
        )
        if res.status_code == 404:
            sr = requests.get(
                "https://api.coingecko.com/api/v3/search",
                params={"query": coin}, timeout=8
            )
            coins = sr.json().get("coins", [])
            if coins:
                coin_id = coins[0]["id"]
                res = requests.get(
                    "https://api.coingecko.com/api/v3/coins/" + coin_id,
                    params={"localization": "false", "tickers": "false",
                            "community_data": "false", "developer_data": "false"},
                    timeout=10
                )
            else:
                return "Could not find cryptocurrency: " + coin

        data   = res.json()
        market = data.get("market_data", {})
        name   = data.get("name", coin)
        symbol = data.get("symbol", "").upper()

        def fmt(n):
            if isinstance(n, (int, float)):
                if n >= 1_000_000_000:
                    return "$" + "{:.2f}".format(n / 1_000_000_000) + "B"
                if n >= 1_000_000:
                    return "$" + "{:.2f}".format(n / 1_000_000) + "M"
                return "$" + "{:,.2f}".format(n)
            return str(n)

        def pct(n):
            if isinstance(n, (int, float)):
                return ("+" if n >= 0 else "-") + "{:.2f}".format(abs(n)) + "%"
            return "N/A"

        price = market.get("current_price", {}).get("usd", 0)
        lines = [
            name + " (" + symbol + ") -- Real-time price",
            "Price:      $" + "{:,.2f}".format(price) + " USD",
            "24h Change: " + pct(market.get("price_change_percentage_24h", 0)),
            "7d Change:  " + pct(market.get("price_change_percentage_7d", 0)),
            "24h High:   " + fmt(market.get("high_24h", {}).get("usd", "N/A")),
            "24h Low:    " + fmt(market.get("low_24h", {}).get("usd", "N/A")),
            "Market Cap: " + fmt(market.get("market_cap", {}).get("usd", "N/A")),
            "24h Volume: " + fmt(market.get("total_volume", {}).get("usd", "N/A")),
            "CMC Rank:   #" + str(data.get("market_cap_rank", "N/A")),
            "Updated:    " + market.get("last_updated", "")[:19].replace("T", " ") + " UTC",
        ]
        return "\n".join(lines)

    except Exception as e:
        return "Could not fetch price for " + coin + ": " + str(e)


# ------------------------------------------------------------------ #
# Gemini API helpers
# ------------------------------------------------------------------ #

def sse(data):
    """Format a dict as an SSE data line."""
    return "data: " + json.dumps(data) + "\n\n"


def chat_with_tools(model, messages, system=None,
                    temperature=0.7, max_tokens=2048):
    """
    Generator that streams Gemini responses with tool calling support.

    Uses OpenAI-compatible endpoint of Google AI Studio.
    Streaming via SSE: each chunk is a JSON delta.

    Flow:
      1. Stream response — forward tokens live
      2. If tool_calls in response: execute tools, append results, stream again
      3. Repeat up to 5 rounds
    """

    def make_messages(msgs, system_prompt):
        """Build messages list with optional system prompt."""
        result = []
        if system_prompt:
            result.append({"role": "system", "content": system_prompt})
        result.extend(msgs)
        return result

    def convert_messages(msgs):
        """Convert OpenAI-style messages to Gemini native format."""
        contents = []
        system_text = ""
        for m in msgs:
            role = m.get("role", "user")
            content = m.get("content", "") or ""
            if role == "system":
                system_text = content
                continue
            # Map roles
            if role == "assistant":
                gemini_role = "model"
            elif role == "tool":
                gemini_role = "user"
                content = "Tool result: " + content
            else:
                gemini_role = "user"
            # Handle tool_calls in assistant messages
            tool_calls = m.get("tool_calls", [])
            if tool_calls:
                parts = []
                if content:
                    parts.append({"text": content})
                for tc in tool_calls:
                    try:
                        args = json.loads(tc["function"]["arguments"])
                    except Exception:
                        args = {}
                    parts.append({
                        "functionCall": {
                            "name": tc["function"]["name"],
                            "args": args
                        }
                    })
                contents.append({"role": "model", "parts": parts})
                continue
            contents.append({
                "role" : gemini_role,
                "parts": [{"text": content}]
            })
        return contents, system_text

    def make_payload(msgs, include_tools=True):
        contents, system_text = convert_messages(msgs)
        p = {
            "contents": contents,
            "generationConfig": {
                "temperature"    : temperature,
                "maxOutputTokens": max_tokens,
            }
        }
        if system_text:
            p["systemInstruction"] = {"parts": [{"text": system_text}]}
        if include_tools and TOOLS:
            # Convert OpenAI tool format to Gemini format
            gemini_tools = []
            for t in TOOLS:
                fn = t["function"]
                gemini_tools.append({
                    "functionDeclarations": [{
                        "name"       : fn["name"],
                        "description": fn["description"],
                        "parameters" : fn.get("parameters", {})
                    }]
                })
            p["tools"] = gemini_tools
        return p

    def stream_request(payload):
        """Make streaming request to Gemini native API, yield parsed chunks."""
        url = (GEMINI_BASE + "/models/" + model +
               ":streamGenerateContent?alt=sse&key=" + GEMINI_KEY)
        with requests.post(
            url,
            headers={"Content-Type": "application/json"},
            json=payload,
            stream=True,
            timeout=120
        ) as res:
            if res.status_code != 200:
                yield {"error": res.text}
                return
            for line in res.iter_lines():
                if not line:
                    continue
                line = line.decode("utf-8") if isinstance(line, bytes) else line
                if line.startswith("data: "):
                    data = line[6:].strip()
                    if data == "[DONE]":
                        return
                    try:
                        yield json.loads(data)
                    except json.JSONDecodeError:
                        continue

    working_messages = make_messages(messages, system)

    for round_num in range(5):
        include_tools   = (round_num == 0)
        full_content    = ""
        tool_calls_acc  = {}   # id -> {name, arguments}
        got_tool_call   = False

        try:
            payload = make_payload(working_messages, include_tools)
            for chunk in stream_request(payload):

                if "error" in chunk:
                    yield sse({"token": "Error: " + chunk["error"]})
                    yield sse({"done": True})
                    return

                # Native Gemini SSE format
                candidates = chunk.get("candidates", [])
                if not candidates:
                    continue

                candidate    = candidates[0]
                finish_reason = candidate.get("finishReason", "")
                parts         = candidate.get("content", {}).get("parts", [])

                for part in parts:
                    # Text token
                    text = part.get("text", "")
                    if text:
                        full_content += text
                        yield sse({"token": text})

                    # Function call
                    fn_call = part.get("functionCall")
                    if fn_call:
                        idx = len(tool_calls_acc)
                        tool_calls_acc[idx] = {
                            "id"       : "call_" + str(idx),
                            "name"     : fn_call.get("name", ""),
                            "arguments": json.dumps(fn_call.get("args", {}))
                        }

                if finish_reason in ("STOP", "MAX_TOKENS"):
                    if tool_calls_acc:
                        got_tool_call = True

        except requests.exceptions.ConnectionError:
            yield sse({"token": "Cannot connect to Gemini API."})
            yield sse({"done": True})
            return
        except Exception as e:
            yield sse({"token": "Error: " + str(e)})
            yield sse({"done": True})
            return

        if not got_tool_call:
            yield sse({"done": True})
            return

        # Append assistant message with function calls
        if full_content:
            working_messages.append({
                "role"   : "assistant",
                "content": full_content
            })

        # Execute each tool and append result
        for idx in sorted(tool_calls_acc.keys()):
            tc      = tool_calls_acc[idx]
            fn_name = tc["name"]
            try:
                fn_args = json.loads(tc["arguments"])
            except Exception:
                fn_args = {}

            if fn_name == "web_search":
                query = fn_args.get("query", "")
                yield sse({"token": "\n\nSearching: " + query + "...\n\n"})
                result = format_search_results(query, web_search(query))

            elif fn_name == "get_crypto_price":
                coin = fn_args.get("coin", "bitcoin")
                yield sse({"token": "\n\nFetching price: " + coin + "...\n\n"})
                result = get_crypto_price(coin)

            else:
                result = "Unknown tool: " + fn_name

            working_messages.append({
                "role"   : "tool",
                "content": result
            })

    yield sse({"done": True})


# ------------------------------------------------------------------ #
# Routes
# ------------------------------------------------------------------ #

def setup_routes(app):

    @app.route('/')
    def index():
        return render_template('index.html', models=AVAILABLE_MODELS)

    @app.route('/chat', methods=['POST'])
    def chat():
        data        = request.get_json(silent=True) or {}
        model       = data.get('model', 'gemini-2.0-flash')
        history     = data.get('history', [])
        system      = data.get('system', '')
        temperature = float(data.get('temperature', 0.7))
        max_tokens  = int(data.get('max_tokens', 2048))

        if not GEMINI_KEY:
            def err():
                yield 'data: {"token":"GEMINI_API_KEY not set in .env"}\n\n'
                yield 'data: {"done":true}\n\n'
            return Response(stream_with_context(err()),
                            mimetype='text/event-stream')

        return Response(
            stream_with_context(
                chat_with_tools(model, history, system, temperature, max_tokens)
            ),
            mimetype='text/event-stream',
            headers={
                'Cache-Control'    : 'no-cache',
                'X-Accel-Buffering': 'no',
            }
        )

    @app.route('/models')
    def models():
        from flask import jsonify
        return jsonify({'models': AVAILABLE_MODELS})
