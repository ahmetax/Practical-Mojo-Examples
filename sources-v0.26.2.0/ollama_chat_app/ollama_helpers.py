"""
Ollama Chat App Flask route handler.
Supports tool calling with DuckDuckGo web search.
"""

import json
import os
import requests
from flask import render_template, request, Response, stream_with_context

# Load .env file if it exists
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
    print("⚠️  Warning: TAVILY_API_KEY not set. Create a .env file.")
    print("   cp .env.example .env  →  then add your key.")

# ------------------------------------------------------------------ #
# Tool definition — Ollama'ya bildirilen araçlar
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
# DuckDuckGo search
# ------------------------------------------------------------------ #

def web_search(query, max_results=5):
    """
    Search the web using Tavily API.
    Returns a list of result dicts with title, url, content.
    """
    results = []
    try:
        res = requests.post(
            "https://api.tavily.com/search",
            json={
                "api_key"        : TAVILY_KEY,
                "query"          : query,
                "max_results"    : max_results,
                "search_depth"   : "basic",
                "include_answer" : True,
                "include_raw_content": False,
            },
            timeout=15
        )
        data = res.json()

        # Tavily direct answer (featured snippet)
        if data.get("answer"):
            results.append({
                "title"  : "Direct Answer",
                "url"    : "",
                "snippet": data["answer"]
            })

        # Individual results
        for r in data.get("results", []):
            results.append({
                "title"  : r.get("title", ""),
                "url"    : r.get("url", ""),
                "snippet": r.get("content", "")
            })

    except Exception as e:
        results.append({
            "title"  : "Search error",
            "url"    : "",
            "snippet": f"Tavily search failed: {e}"
        })
    return results


# Keep old name as alias for compatibility
duckduckgo_search = web_search


# ------------------------------------------------------------------ #
# CoinGecko API — real-time crypto prices (no API key needed)
# ------------------------------------------------------------------ #

COIN_ID_MAP = {
    "btc"      : "bitcoin",
    "eth"      : "ethereum",
    "sol"      : "solana",
    "bnb"      : "binancecoin",
    "xrp"      : "ripple",
    "ada"      : "cardano",
    "doge"     : "dogecoin",
    "dot"      : "polkadot",
    "matic"    : "matic-network",
    "ltc"      : "litecoin",
    "avax"     : "avalanche-2",
    "link"     : "chainlink",
    "uni"      : "uniswap",
    "atom"     : "cosmos",
    "xlm"      : "stellar",
}


def get_crypto_price(coin):
    """
    Fetch real-time crypto price from CoinGecko API.
    Returns a formatted string with price and market data.
    """
    # Normalize coin name
    coin_lower = coin.lower().strip()
    coin_id    = COIN_ID_MAP.get(coin_lower, coin_lower)

    try:
        res = requests.get(
            f"https://api.coingecko.com/api/v3/coins/{coin_id}",
            params={"localization": "false", "tickers": "false",
                    "community_data": "false", "developer_data": "false"},
            timeout=10,
            headers={"User-Agent": "Mozilla/5.0"}
        )

        if res.status_code == 404:
            # Try searching by name
            search_res = requests.get(
                "https://api.coingecko.com/api/v3/search",
                params={"query": coin},
                timeout=8
            )
            coins = search_res.json().get("coins", [])
            if coins:
                coin_id = coins[0]["id"]
                res = requests.get(
                    f"https://api.coingecko.com/api/v3/coins/{coin_id}",
                    params={"localization": "false", "tickers": "false",
                            "community_data": "false", "developer_data": "false"},
                    timeout=10
                )
            else:
                return f"Could not find cryptocurrency: {coin}"

        data   = res.json()
        market = data.get("market_data", {})
        name   = data.get("name", coin)
        symbol = data.get("symbol", "").upper()

        price_usd  = market.get("current_price", {}).get("usd", "N/A")
        change_24h = market.get("price_change_percentage_24h", 0)
        change_7d  = market.get("price_change_percentage_7d", 0)
        market_cap = market.get("market_cap", {}).get("usd", "N/A")
        volume_24h = market.get("total_volume", {}).get("usd", "N/A")
        high_24h   = market.get("high_24h", {}).get("usd", "N/A")
        low_24h    = market.get("low_24h", {}).get("usd", "N/A")
        rank       = data.get("market_cap_rank", "N/A")
        updated    = market.get("last_updated", "")[:19].replace("T", " ")

        def fmt(n):
            if isinstance(n, (int, float)):
                if n >= 1_000_000_000:
                    return "$" + f"{n/1_000_000_000:.2f}" + "B"
                if n >= 1_000_000:
                    return "$" + f"{n/1_000_000:.2f}" + "M"
                return "$" + f"{n:,.2f}"
            return str(n)

        def pct(n):
            if isinstance(n, (int, float)):
                arrow = "+" if n >= 0 else "-"
                return arrow + f"{abs(n):.2f}%"
            return "N/A"

        lines = [
            name + " (" + symbol + ") -- Real-time price",
            "Price:      $" + f"{price_usd:,.2f}" + " USD",
            "24h Change: " + pct(change_24h),
            "7d Change:  " + pct(change_7d),
            "24h High:   " + fmt(high_24h),
            "24h Low:    " + fmt(low_24h),
            "Market Cap: " + fmt(market_cap),
            "24h Volume: " + fmt(volume_24h),
            "CMC Rank:   #" + str(rank),
            "Updated:    " + updated + " UTC",
        ]
        return "".join(lines)

    except Exception as e:
        return f"Could not fetch price for {coin}: {e}"


def format_search_results(query, results):
    """Format search results as a readable string for the model."""
    if not results:
        return f"No results found for: {query}"

    lines = [f"Web search results for: '{query}'\n"]
    for i, r in enumerate(results, 1):
        lines.append(f"{i}. {r['title']}")
        if r['url']:
            lines.append(f"   URL: {r['url']}")
        lines.append(f"   {r['snippet']}")
        lines.append("")

    return "\n".join(lines)


# ------------------------------------------------------------------ #
# Ollama API helpers
# ------------------------------------------------------------------ #

def get_models():
    """Return list of installed Ollama model names."""
    try:
        res = requests.get(f"{OLLAMA_BASE}/api/tags", timeout=3)
        if res.status_code == 200:
            return [m['name'] for m in res.json().get('models', [])]
    except Exception:
        pass
    return []


def chat_with_tools(model, messages, system=None,
                    temperature=0.7, max_tokens=2048):
    """
    Generator that handles tool calling + streaming.
    Yields SSE strings.

    Flow:
      1. Send messages to Ollama with tool definitions
      2. If model calls web_search → execute it → append result
      3. Send updated messages back → stream final response
    """

    def build_payload(msgs, stream=False):
        p = {
            "model"   : model,
            "messages": msgs,
            "tools"   : TOOLS,
            "stream"  : stream,
            "options" : {
                "temperature": temperature,
                "num_predict": max_tokens,
            }
        }
        if system:
            p["system"] = system
        return p

    working_messages = list(messages)

    # ── Step 1: non-streaming call to check for tool use ── #
    try:
        res = requests.post(
            f"{OLLAMA_BASE}/api/chat",
            json=build_payload(working_messages, stream=False),
            timeout=120
        )
        data = res.json()
    except Exception as e:
        yield f"data: {json.dumps({'token': f'❌ Ollama error: {e}'})}\n\n"
        yield f"data: {json.dumps({'done': True})}\n\n"
        return

    msg = data.get("message", {})

    # ── Step 2: handle tool calls ── #
    tool_calls = msg.get("tool_calls", [])

    if tool_calls:
        # Append assistant's tool call message
        working_messages.append({
            "role"      : "assistant",
            "content"   : msg.get("content", ""),
            "tool_calls": tool_calls
        })

        for tc in tool_calls:
            fn_name = tc.get("function", {}).get("name", "")
            fn_args = tc.get("function", {}).get("arguments", {})

            if fn_name == "web_search":
                query = fn_args.get("query", "")
                yield f"data: {json.dumps({'token': f'🔍 Searching: *{query}*\\n\\n'})}\n\n"

                results     = web_search(query)
                result_text = format_search_results(query, results)

                working_messages.append({
                    "role"   : "tool",
                    "content": result_text
                })

            elif fn_name == "get_crypto_price":
                coin = fn_args.get("coin", "bitcoin")
                yield f"data: {json.dumps({'token': f'📈 Fetching price: *{coin}*\\n\\n'})}\n\n"

                price_text = get_crypto_price(coin)

                working_messages.append({
                    "role"   : "tool",
                    "content": price_text
                })

        # ── Step 3: stream final response after tool use ── #
        try:
            with requests.post(
                f"{OLLAMA_BASE}/api/chat",
                json=build_payload(working_messages, stream=True),
                stream=True,
                timeout=120
            ) as stream_res:
                for line in stream_res.iter_lines():
                    if not line:
                        continue
                    try:
                        chunk   = json.loads(line)
                        token   = chunk.get("message", {}).get("content", "")
                        is_done = chunk.get("done", False)

                        if token:
                            yield f"data: {json.dumps({'token': token})}\n\n"
                        if is_done:
                            yield f"data: {json.dumps({'done': True})}\n\n"
                            return
                    except json.JSONDecodeError:
                        continue

        except Exception as e:
            yield f"data: {json.dumps({'token': f'❌ Stream error: {e}'})}\n\n"
            yield f"data: {json.dumps({'done': True})}\n\n"

    else:
        # ── No tool call: stream direct response ── #
        direct_content = msg.get("content", "")
        if direct_content:
            # Yield in chunks for smoother display
            chunk_size = 4
            for i in range(0, len(direct_content), chunk_size):
                chunk = direct_content[i:i+chunk_size]
                yield f"data: {json.dumps({'token': chunk})}\n\n"

        yield f"data: {json.dumps({'done': True})}\n\n"


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
                chat_with_tools(
                    model, history, system, temperature, max_tokens
                )
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
