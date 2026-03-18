"""
Web Scraper Flask route handler helper.
Imported by scraper_app.mojo via Python.import_module().
"""

import json
import time
import uuid
from datetime import datetime
from urllib.parse import urljoin, urlparse

import requests
from bs4 import BeautifulSoup
from flask import (
    render_template, request, redirect,
    url_for, flash, jsonify, send_file
)
import io

# In-memory history store: { id: result_dict }
history = {}

USER_AGENTS = {
    'default': 'python-requests/2.31.0',
    'chrome' : ('Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                'AppleWebKit/537.36 (KHTML, like Gecko) '
                'Chrome/120.0.0.0 Safari/537.36'),
    'firefox': ('Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) '
                'Gecko/20100101 Firefox/121.0'),
    'bot'    : 'Googlebot/2.1 (+http://www.google.com/bot.html)',
}


# ------------------------------------------------------------------ #
# Scraping helpers
# ------------------------------------------------------------------ #
def fetch_page(url, timeout=10, user_agent='default'):
    headers = {'User-Agent': USER_AGENTS.get(user_agent, USER_AGENTS['default'])}
    resp = requests.get(url, headers=headers, timeout=timeout,
                        allow_redirects=True)
    resp.raise_for_status()
    return resp


def extract_meta(soup):
    meta = {}
    # Title
    if soup.title and soup.title.string:
        meta['title'] = soup.title.string.strip()
    # Standard meta tags
    for tag in soup.find_all('meta'):
        name    = tag.get('name') or tag.get('property') or ''
        content = tag.get('content', '')
        if name and content:
            name = name.lower().replace('og:', 'og:')
            meta[name] = content.strip()
    # Charset
    charset = soup.find('meta', charset=True)
    if charset:
        meta['charset'] = charset.get('charset', '')
    return meta


def extract_headings(soup):
    headings = []
    for tag in soup.find_all(['h1', 'h2', 'h3', 'h4', 'h5', 'h6']):
        text = tag.get_text(strip=True)
        if text:
            headings.append({'tag': tag.name.upper(), 'text': text})
    return headings


def extract_links(soup, base_url, max_links=50):
    links = []
    seen  = set()
    for tag in soup.find_all('a', href=True):
        href = tag['href'].strip()
        if not href or href.startswith(('#', 'javascript:', 'mailto:', 'tel:')):
            continue
        full = urljoin(base_url, href)
        if full in seen:
            continue
        seen.add(full)
        text = tag.get_text(strip=True)
        links.append({'href': full, 'text': text})
        if len(links) >= max_links:
            break
    return links


def extract_images(soup, base_url, max_images=30):
    images = []
    seen   = set()
    for tag in soup.find_all('img', src=True):
        src = tag['src'].strip()
        if not src or src.startswith('data:'):
            continue
        full = urljoin(base_url, src)
        if full in seen:
            continue
        seen.add(full)
        alt = tag.get('alt', '').strip()
        images.append({'src': full, 'alt': alt})
        if len(images) >= max_images:
            break
    return images


def extract_text(soup):
    # Remove scripts, styles, nav, footer
    for tag in soup(['script', 'style', 'nav', 'footer', 'header']):
        tag.decompose()
    text = soup.get_text(separator='\n')
    # Clean up blank lines
    lines = [l.strip() for l in text.splitlines() if l.strip()]
    return '\n'.join(lines)


def extract_tables(soup):
    tables = []
    for tbl in soup.find_all('table'):
        headers = []
        rows    = []
        # Headers
        for th in tbl.find_all('th'):
            headers.append(th.get_text(strip=True))
        # Rows
        for tr in tbl.find_all('tr'):
            cells = [td.get_text(strip=True) for td in tr.find_all('td')]
            if cells:
                rows.append(cells)
        if rows:
            tables.append({'headers': headers, 'rows': rows})
    return tables


def scrape(url, options):
    start = time.time()
    resp  = fetch_page(
        url,
        timeout    = options.get('timeout', 10),
        user_agent = options.get('user_agent', 'default')
    )
    elapsed = round(time.time() - start, 2)

    soup   = BeautifulSoup(resp.text, 'html.parser')
    result = {
        'id'         : str(uuid.uuid4())[:8],
        'url'        : url,
        'status_code': resp.status_code,
        'elapsed'    : elapsed,
        'scraped_at' : datetime.now().strftime('%Y-%m-%d %H:%M'),
        'title'      : soup.title.string.strip() if soup.title and soup.title.string else '',
    }

    if options.get('get_meta'):
        result['meta'] = extract_meta(soup)

    if options.get('get_headings'):
        result['headings'] = extract_headings(soup)

    if options.get('get_links'):
        result['links'] = extract_links(
            soup, url, options.get('max_links', 50)
        )

    if options.get('get_images'):
        result['images'] = extract_images(
            soup, url, options.get('max_images', 30)
        )

    if options.get('get_text'):
        result['text'] = extract_text(soup)

    if options.get('get_tables'):
        result['tables'] = extract_tables(soup)

    return result


# ------------------------------------------------------------------ #
# Routes
# ------------------------------------------------------------------ #
def setup_routes(app):

    @app.route('/')
    def index():
        last_url = request.args.get('url', '')
        return render_template('index.html', last_url=last_url)

    # ---------------------------------------------------------------- #
    # POST /scrape — run scraper
    # ---------------------------------------------------------------- #
    @app.route('/scrape', methods=['POST'])
    def do_scrape():
        url = request.form.get('url', '').strip()
        if not url:
            flash('Please enter a URL.', 'error')
            return redirect(url_for('index'))

        if not url.startswith(('http://', 'https://')):
            url = 'https://' + url

        options = {
            'get_meta'    : bool(request.form.get('get_meta')),
            'get_headings': bool(request.form.get('get_headings')),
            'get_links'   : bool(request.form.get('get_links')),
            'get_images'  : bool(request.form.get('get_images')),
            'get_text'    : bool(request.form.get('get_text')),
            'get_tables'  : bool(request.form.get('get_tables')),
            'timeout'     : int(request.form.get('timeout', 10) or 10),
            'max_links'   : int(request.form.get('max_links', 50) or 50),
            'max_images'  : int(request.form.get('max_images', 30) or 30),
            'user_agent'  : request.form.get('user_agent', 'default'),
        }

        try:
            result = scrape(url, options)
        except requests.exceptions.Timeout:
            flash(f'Request timed out after {options["timeout"]}s.', 'error')
            return redirect(url_for('index', url=url))
        except requests.exceptions.ConnectionError:
            flash('Could not connect to the URL. Check the address.', 'error')
            return redirect(url_for('index', url=url))
        except requests.exceptions.HTTPError as e:
            flash(f'HTTP error: {e}', 'error')
            return redirect(url_for('index', url=url))
        except Exception as e:
            flash(f'Scraping error: {e}', 'error')
            return redirect(url_for('index', url=url))

        # Save to history
        history[result['id']] = result
        return render_template('result.html', result=result)

    # ---------------------------------------------------------------- #
    # GET /result/<id> — view a past result
    # ---------------------------------------------------------------- #
    @app.route('/result/<result_id>')
    def view_result(result_id):
        result = history.get(result_id)
        if not result:
            flash('Result not found.', 'error')
            return redirect(url_for('index'))
        return render_template('result.html', result=result)

    # ---------------------------------------------------------------- #
    # GET /download/<id> — download result as JSON
    # ---------------------------------------------------------------- #
    @app.route('/download/<result_id>')
    def download_result(result_id):
        result = history.get(result_id)
        if not result:
            flash('Result not found.', 'error')
            return redirect(url_for('index'))
        json_str  = json.dumps(result, ensure_ascii=False, indent=2)
        buf       = io.BytesIO(json_str.encode('utf-8'))
        buf.seek(0)
        filename  = f"scrape_{result_id}.json"
        return send_file(buf, mimetype='application/json',
                         as_attachment=True, download_name=filename)

    # ---------------------------------------------------------------- #
    # GET /history — list past scrapes
    # ---------------------------------------------------------------- #
    @app.route('/history')
    def view_history():
        items = sorted(history.values(),
                       key=lambda x: x['scraped_at'], reverse=True)
        return render_template('history.html', history=items)

    # ---------------------------------------------------------------- #
    # POST /history/clear — clear all history
    # ---------------------------------------------------------------- #
    @app.route('/history/clear', methods=['POST'])
    def clear_history():
        history.clear()
        flash('History cleared.', 'success')
        return redirect(url_for('view_history'))
