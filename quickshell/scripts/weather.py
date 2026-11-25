#!/usr/bin/env python3
"""
weather.py — Open-Meteo current weather + daily hi/low helper with runtime cache
for Quickshell's Clock & Calendar widget (zero API keys required).
"""
import json
import os
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

CACHE_PATH = Path(os.environ.get("XDG_RUNTIME_DIR") or "/tmp") / "quickshell_weather_cache.json"
CACHE_TTL = 900  # 15 minutes


def _esc(val: str) -> str:
    return (
        str(val or "")
        .replace("\\", "\\\\")
        .replace("\n", "\\n")
        .replace("=", "\\e")
        .replace(",", "\\c")
        .replace(";", "\\s")
        .replace("|", "\\p")
    )


def _fetch_json(url: str, timeout: int = 6) -> dict:
    req = urllib.request.Request(url, headers={"User-Agent": "quickshell-weather/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def _wmo_condition(code: int) -> str:
    if code == 0:
        return "clear"
    if code in (1, 2):
        return "partly cloudy"
    if code == 3:
        return "overcast"
    if code in (45, 48):
        return "foggy"
    if code in (51, 53, 55, 56, 57):
        return "drizzle"
    if code in (61, 63, 65, 66, 67, 80, 81, 82):
        return "rain"
    if code in (71, 73, 75, 77, 85, 86):
        return "snow"
    if code in (95, 96, 99):
        return "thunderstorm"
    return "cloudy"


def _resolve_coords(query: str) -> tuple[float, float, str]:
    q = (query or "").strip()
    if q:
        url = "https://geocoding-api.open-meteo.com/v1/search?count=1&language=en&format=json&name=" + urllib.parse.quote(q)
        data = _fetch_json(url)
        results = data.get("results") or []
        if results:
            r = results[0]
            name = r.get("name", q)
            admin = r.get("admin1", "")
            label = f"{name}, {admin}" if admin else name
            return float(r["latitude"]), float(r["longitude"]), label

    # Fallback: IP geolocation (tries ipwho.is then ipapi.co)
    for url in ("https://ipwho.is/", "https://ipapi.co/json/"):
        try:
            geo = _fetch_json(url, timeout=5)
            lat = geo.get("latitude")
            lon = geo.get("longitude")
            city = geo.get("city") or ""
            region = geo.get("region_code") or geo.get("region") or ""
            if lat is not None and lon is not None:
                label = f"{city}, {region}".strip(", ") or "local"
                return float(lat), float(lon), label
        except Exception:
            continue

    raise RuntimeError("could not resolve location (offline or dns failed)")


def get_weather(location: str = "", force: bool = False) -> dict:
    loc_key = (location or "").strip().lower()
    now = time.time()

    if not force and CACHE_PATH.is_file():
        try:
            cached = json.loads(CACHE_PATH.read_text(encoding="utf-8"))
            if cached.get("_key") == loc_key and (now - cached.get("_ts", 0)) < CACHE_TTL:
                return cached
        except Exception:
            pass

    lat, lon, city_label = _resolve_coords(location)
    url = (
        f"https://api.open-meteo.com/v1/forecast?"
        f"latitude={lat:.4f}&longitude={lon:.4f}"
        f"&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day"
        f"&daily=temperature_2m_max,temperature_2m_min"
        f"&forecast_days=1&timezone=auto"
    )
    data = _fetch_json(url)
    cur = data.get("current") or {}
    daily = data.get("daily") or {}

    temp_c = float(cur.get("temperature_2m", 0.0))
    feels_c = float(cur.get("apparent_temperature", temp_c))
    hi_list = daily.get("temperature_2m_max") or [temp_c]
    lo_list = daily.get("temperature_2m_min") or [temp_c]
    hi_c = float(hi_list[0])
    lo_c = float(lo_list[0])
    code = int(cur.get("weather_code", 0))

    res = {
        "ok": True,
        "_key": loc_key,
        "_ts": now,
        "city": city_label,
        "temp_c": round(temp_c, 1),
        "temp_f": round(temp_c * 9.0 / 5.0 + 32.0, 1),
        "feels_c": round(feels_c, 1),
        "feels_f": round(feels_c * 9.0 / 5.0 + 32.0, 1),
        "high_c": round(hi_c, 1),
        "high_f": round(hi_c * 9.0 / 5.0 + 32.0, 1),
        "low_c": round(lo_c, 1),
        "low_f": round(lo_c * 9.0 / 5.0 + 32.0, 1),
        "humidity": int(cur.get("relative_humidity_2m", 0)),
        "wind_kmh": round(float(cur.get("wind_speed_10m", 0.0)), 1),
        "code": code,
        "cond": _wmo_condition(code),
        "is_day": bool(cur.get("is_day", 1)),
    }

    try:
        CACHE_PATH.write_text(json.dumps(res), encoding="utf-8")
    except OSError:
        pass
    return res


def main() -> None:
    args = sys.argv[1:]
    force = "--force" in args or "-f" in args
    loc_args = [a for a in args if a not in ("--force", "-f", "fetch")]
    loc = " ".join(loc_args).strip()

    try:
        w = get_weather(loc, force=force)
        for k, v in w.items():
            if k.startswith("_"):
                continue
            if isinstance(v, bool):
                print(f"{k}={'true' if v else 'false'}")
            else:
                print(f"{k}={_esc(str(v))}")
    except Exception as exc:
        print("ok=false")
        print(f"error={_esc(str(exc))}")


if __name__ == "__main__":
    main()
