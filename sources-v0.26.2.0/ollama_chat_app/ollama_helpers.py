"""
Ollama Chat App Flask route handler.
Supports tool calling with Tavily web search and CoinGecko crypto prices.
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

OLLAMA_BASE = "http://localhost:11434"
TAVILY_KEY  = os.environ.get("TAVILY_API_KEY", "")

if not TAVILY_KEY:
    print("Warning: TAVILY_API_KEY not set. Create a .env file.")


# ------------------------------------------------------------------ #
# Tool definitions
# ------------------------------------------------------------------ #

TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "web_search",
            "description": (
                "Search the web for current information, news, recent events, "
                "or any topic that may have changed after your training cutoff. "
                "Use this whenever the user asks about recent events, current data, "
                "or anything you are uncertain about."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "The search query to look up on the web."
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
                "Get the current real-time price and market data for a "
                "cryptocurrency. Use this when the user asks about crypto prices, "
                "market cap, or 24h change for coins like Bitcoin, Ethereum, etc."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "coin": {
                        "type": "string",
                        "description": (
                            "The cryptocurrency name or symbol. "
                            "Examples: bitcoin, ethereum, solana, BTC, ETH"
                        )
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
    """Format search results as a readable string for the model."""
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
# Ollama helpers
# ------------------------------------------------------------------ #

def get_models():
    """Return list of installed Ollama model names."""
    try:
        res = requests.get(OLLAMA_BASE + "/api/tags", timeout=3)
        if res.status_code == 200:
            return [m['name'] for m in res.json().get('models', [])]
    except Exception:
        pass
    return []


def sse(data):
    """Format a dict as an SSE data line."""
    return "data: " + json.dumps(data) + "\n\n"


def chat_with_tools(model, messages, system=None,
                    temperature=0.7, max_tokens=2048):
    """
    Generator that streams Ollama responses with tool calling support.

    Strategy:
      - Always use stream=True so thinking + content tokens arrive live
      - Accumulate full response to detect tool_calls in the done chunk
      - If tool called: execute tool, append result, stream again
      - thinking tokens -> SSE 'thinking' events
      - content tokens  -> SSE 'token' events
    """

    def make_payload(msgs, include_tools=True):
        p = {
            "model"      : model,
            "messages"   : msgs,
            "stream"     : True,
            "keep_alive" : "10m",
            "options"    : {
                "temperature": temperature,
                "num_predict": max_tokens,
            }
        }
        if include_tools:
            p["tools"] = TOOLS
        if system:
            p["system"] = system
        return p

    working_messages = list(messages)

    for round_num in range(5):
        include_tools  = (round_num == 0)
        full_content   = ""
        tool_calls_buf = []
        got_tool_call  = False

        try:
            with requests.post(
                OLLAMA_BASE + "/api/chat",
                json=make_payload(working_messages, include_tools),
                stream=True,
                timeout=120
            ) as res:
                for line in res.iter_lines():
                    if not line:
                        continue
                    try:
                        chunk    = json.loads(line)
                        msg      = chunk.get("message", {})
                        thinking = msg.get("thinking", "")
                        token    = msg.get("content", "")
                        is_done  = chunk.get("done", False)

                        if thinking:
                            yield sse({"thinking": thinking})

                        if token:
                            full_content += token
                            yield sse({"token": token})

                        if is_done:
                            tc = msg.get("tool_calls", [])
                            if tc:
                                tool_calls_buf = tc
                                got_tool_call  = True
                            break

                    except json.JSONDecodeError:
                        continue

        except requests.exceptions.ConnectionError:
            yield sse({"token": "Cannot connect to Ollama. Is it running?"})
            yield sse({"done": True})
            return
        except Exception as e:
            yield sse({"token": "Error: " + str(e)})
            yield sse({"done": True})
            return

        if not got_tool_call:
            yield sse({"done": True})
            return

        # Execute tools
        working_messages.append({
            "role"      : "assistant",
            "content"   : full_content,
            "tool_calls": tool_calls_buf
        })

        for tc in tool_calls_buf:
            fn_name = tc.get("function", {}).get("name", "")
            fn_args = tc.get("function", {}).get("arguments", {})

            if fn_name == "web_search":
                query = fn_args.get("query", "")
                yield sse({"token": "\n\nSearching: " + query + "...\n\n"})
                result_text = format_search_results(query, web_search(query))
                working_messages.append({"role": "tool", "content": result_text})

            elif fn_name == "get_crypto_price":
                coin = fn_args.get("coin", "bitcoin")
                yield sse({"token": "\n\nFetching price: " + coin + "...\n\n"})
                working_messages.append({
                    "role"   : "tool",
                    "content": get_crypto_price(coin)
                })

    yield sse({"done": True})


# ------------------------------------------------------------------ #
# Routes
# ------------------------------------------------------------------ #

def setup_routes(app):

    @app.route('/')
    def index():
        models = get_models()
        return render_template('index.html', models=models)

    @app.route('/chat', methods=['POST'])
    def chat():
        data        = request.get_json(silent=True) or {}
        model       = data.get('model', '')
        history     = data.get('history', [])
        system      = data.get('system', '')
        temperature = float(data.get('temperature', 0.7))
        max_tokens  = int(data.get('max_tokens', 2048))

        if not model:
            def err():
                yield 'data: {"token":"No model selected."}\n\n'
                yield 'data: {"done":true}\n\n'
            return Response(
                stream_with_context(err()),
                mimetype='text/event-stream'
            )

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
        return jsonify({'models': get_models()})
