"""
Weather App Flask route handler and OpenWeatherMap API helper.
Imported by weather_app.mojo via Python.import_module().
"""

import requests
from flask import render_template, request, session, flash
from datetime import datetime, timezone

API_BASE    = "https://api.openweathermap.org/data/2.5"
API_KEY     = ""   # Set by setup_routes()
MAX_RECENT  = 5


# ------------------------------------------------------------------ #
# Weather condition code -> emoji icon
# ------------------------------------------------------------------ #
def weather_icon(code):
    if code < 300:   return "⛈"   # thunderstorm
    if code < 400:   return "🌧"   # drizzle
    if code < 600:   return "🌧"   # rain
    if code < 700:   return "❄️"   # snow
    if code < 800:   return "🌫"   # atmosphere (fog, haze...)
    if code == 800:  return "☀️"   # clear
    if code <= 802:  return "⛅"   # few/scattered clouds
    return "☁️"                    # broken/overcast clouds


# ------------------------------------------------------------------ #
# Fetch current weather
# ------------------------------------------------------------------ #
def fetch_current(city):
    url = f"{API_BASE}/weather"
    params = {
        'q'     : city,
        'appid' : API_KEY,
        'units' : 'metric'
    }
    resp = requests.get(url, params=params, timeout=8)
    if resp.status_code == 404:
        return None, "City not found."
    if resp.status_code == 401:
        return None, "Invalid API key."
    if resp.status_code != 200:
        return None, f"API error: {resp.status_code}"

    d = resp.json()

    # Sunrise / sunset in local time
    tz_offset = d['timezone']
    def utc_to_local(ts):
        dt = datetime.fromtimestamp(ts, tz=timezone.utc)
        local_sec = ts + tz_offset
        return datetime.utcfromtimestamp(local_sec).strftime('%H:%M')

    weather = {
        'city'        : d['name'],
        'country'     : d['sys']['country'],
        'temp'        : round(d['main']['temp']),
        'feels_like'  : round(d['main']['feels_like']),
        'description' : d['weather'][0]['description'],
        'icon'        : weather_icon(d['weather'][0]['id']),
        'humidity'    : d['main']['humidity'],
        'wind_speed'  : round(d['wind']['speed'], 1),
        'pressure'    : d['main']['pressure'],
        'visibility'  : round(d.get('visibility', 0) / 1000, 1),
        'sunrise'     : utc_to_local(d['sys']['sunrise']),
        'sunset'      : utc_to_local(d['sys']['sunset']),
    }
    return weather, None


# ------------------------------------------------------------------ #
# Fetch 5-day / 3-hour forecast → aggregate to daily
# ------------------------------------------------------------------ #
def fetch_forecast(city):
    url = f"{API_BASE}/forecast"
    params = {
        'q'     : city,
        'appid' : API_KEY,
        'units' : 'metric',
        'cnt'   : 40
    }
    resp = requests.get(url, params=params, timeout=8)
    if resp.status_code != 200:
        return []

    items = resp.json()['list']

    # Group by date
    days = {}
    for item in items:
        date = item['dt_txt'][:10]
        if date not in days:
            days[date] = {
                'temps'      : [],
                'codes'      : [],
                'descriptions': []
            }
        days[date]['temps'].append(item['main']['temp'])
        days[date]['codes'].append(item['weather'][0]['id'])
        days[date]['descriptions'].append(item['weather'][0]['description'])

    today = datetime.now().strftime('%Y-%m-%d')
    forecast = []
    for date, data in sorted(days.items()):
        if date == today:
            continue   # skip today — shown in current weather
        if len(forecast) >= 5:
            break
        dt = datetime.strptime(date, '%Y-%m-%d')
        # Most frequent weather code
        code = max(set(data['codes']), key=data['codes'].count)
        desc = max(set(data['descriptions']),
                   key=data['descriptions'].count)
        forecast.append({
            'date'       : dt.strftime('%a %d %b'),
            'temp_max'   : round(max(data['temps'])),
            'temp_min'   : round(min(data['temps'])),
            'icon'       : weather_icon(code),
            'description': desc
        })

    return forecast


# ------------------------------------------------------------------ #
# Route setup
# ------------------------------------------------------------------ #
def setup_routes(app, api_key):
    global API_KEY
    API_KEY = api_key

    @app.route('/')
    def index():
        city     = request.args.get('city', '').strip()
        weather  = None
        forecast = []

        # Recent searches stored in session
        if 'recent' not in session:
            session['recent'] = []

        if city:
            weather, error = fetch_current(city)
            if error:
                flash(error, 'error')
            else:
                forecast = fetch_forecast(city)
                # Update recent searches
                recent = session['recent']
                if city not in recent:
                    recent.insert(0, city)
                    session['recent'] = recent[:MAX_RECENT]
                session.modified = True

        return render_template('index.html',
            weather=weather,
            forecast=forecast,
            query=city,
            recent=session.get('recent', [])
        )
