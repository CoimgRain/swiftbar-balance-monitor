#!/usr/bin/env python3
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import pathlib
import ssl
import time
import urllib.error
import urllib.parse
import urllib.request

SERVICE_ID = "{{SERVICE_ID}}"
SERVICE_LABEL = "{{LABEL}}"
CURRENCY = "{{CURRENCY}}"
SUBSCRIPTION_PREFIX = "{{SUBSCRIPTION_PREFIX}}"
BASE_URL_ENV = "{{BASE_URL_ENV}}"
BASE_URL = os.environ.get(BASE_URL_ENV, "{{BASE_URL_DEFAULT}}").rstrip("/")
APP_DIR = pathlib.Path(os.environ.get("{{SERVICE_ENV_PREFIX}}_MONITOR_DIR", pathlib.Path(__file__).resolve().parent))
STATE_FILE = APP_DIR / "state.json"
CACHE_FILE = APP_DIR / "cache.json"
NOOP = "bash=/usr/bin/true terminal=false"


def now_ts() -> int:
    return int(time.time())


def load_json(path: pathlib.Path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default


def save_json(path: pathlib.Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(path)
    try:
        os.chmod(path, 0o600)
    except OSError:
        pass


def build_ssl_context():
    if os.environ.get("{{SERVICE_ENV_PREFIX}}_INSECURE_TLS", "0") == "1":
        return ssl._create_unverified_context()
    return None


def request_json(method: str, path: str, *, data=None, params=None, headers=None, timeout=20):
    url = BASE_URL + path
    if params:
        url += ("&" if "?" in url else "?") + urllib.parse.urlencode(params)
    merged_headers = {
        "Accept": "application/json, text/plain, */*",
        "User-Agent": f"{SERVICE_ID}-SwiftBarMonitor/1.0",
        "Cache-Control": "no-store",
    }
    merged_headers.update(headers or {})
    if data is not None:
        merged_headers["Content-Type"] = "application/json"
    body = json.dumps(data).encode("utf-8") if data is not None else None
    req = urllib.request.Request(url, data=body, method=method.upper(), headers=merged_headers)
    try:
        with urllib.request.urlopen(req, timeout=timeout, context=build_ssl_context()) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
            return json.loads(raw)
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8", errors="replace")
        try:
            payload = json.loads(raw)
        except Exception:
            payload = {"message": raw or str(e)}
        raise RuntimeError(f"HTTP {e.code}: {payload.get('message') or payload}") from e


def auth_headers_from_state() -> dict:
    state = load_json(STATE_FILE, {})
    headers = {}
    token = state.get("token") or os.environ.get("{{SERVICE_ENV_PREFIX}}_TOKEN")
    cookie = state.get("cookie") or os.environ.get("{{SERVICE_ENV_PREFIX}}_COOKIE")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if cookie:
        headers["Cookie"] = cookie
    return headers


def get_display_mode() -> str:
    state = load_json(STATE_FILE, {})
    mode = str(state.get("display_mode") or "used")
    return mode if mode in ("used", "remain") else "used"


def set_display_mode(mode: str) -> None:
    if mode not in ("used", "remain"):
        raise RuntimeError("display mode must be used or remain")
    state = load_json(STATE_FILE, {})
    state["display_mode"] = mode
    state["updated_at"] = now_ts()
    save_json(STATE_FILE, state)


def fetch_all() -> dict:
    headers = auth_headers_from_state()

    # TODO: Replace this placeholder with the site's real endpoints.
    # Example:
    # user = request_json("GET", "/api/user/self", headers=headers)
    # balance = float(user["data"]["quota"]) / 500000
    #
    # Return the normalized object shown below. Do not hard-code secrets.
    raise RuntimeError(
        "fetch_all() is not configured yet. Inspect the site's wallet/profile API "
        "and map its response into the normalized monitor object."
    )

    return {
        "ok": True,
        "label": SERVICE_LABEL,
        "balance": 0.0,
        "currency": CURRENCY,
        "username": "-",
        "updated_at": now_ts(),
        "updated_at_text": dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "subscription": {
            "active": False,
            "used": None,
            "remain": None,
            "total": None,
            "used_percent": None,
            "remain_percent": None,
            "items": [],
        },
    }


def money(value) -> str:
    try:
        return f"{CURRENCY}{float(value):.2f}"
    except Exception:
        return f"{CURRENCY}-"


def format_text(data: dict) -> str:
    if not data.get("ok"):
        return f"{SERVICE_LABEL} alert\n---\nError | color=red\n{data.get('error', 'unknown error')}"

    bal = data.get("balance") or 0
    sub = data.get("subscription") or {}
    mode = get_display_mode()
    pct = sub.get("remain_percent") if mode == "remain" else sub.get("used_percent")
    sub_text = "" if pct is None else f" / {SUBSCRIPTION_PREFIX}{pct:.1f}%"
    lines = [f"{SERVICE_LABEL} {money(bal)}{sub_text}", "---"]
    lines.append(f"Balance: {money(bal)} | {NOOP}")

    if sub.get("total") is not None:
        lines.append(f"Subscription used: {money(sub.get('used') or 0)} / {money(sub.get('total') or 0)} | {NOOP}")
        lines.append(f"Subscription remain: {money(sub.get('remain') or 0)} / {money(sub.get('total') or 0)} | {NOOP}")
        for item in sub.get("items") or []:
            title = item.get("title") or "Subscription"
            used_pct = item.get("used_percent")
            pct_text = "-" if used_pct is None else f"{used_pct:.1f}%"
            lines.append(f"{title}: used {pct_text} | {NOOP}")

    lines.append(f"Account: {data.get('username') or '-'} | {NOOP}")
    lines.append(f"Updated: {data.get('updated_at_text')} | {NOOP}")
    lines.append("---")
    lines.append("Refresh | refresh=true")
    return "\n".join(lines)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--text", action="store_true")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--cache", action="store_true")
    parser.add_argument("--set-display", choices=("used", "remain"))
    args = parser.parse_args(argv)
    try:
        if args.set_display:
            set_display_mode(args.set_display)
            return 0
        data = load_json(CACHE_FILE, {"ok": False, "error": "no cache"}) if args.cache else fetch_all()
        print(format_text(data) if args.text else json.dumps(data, ensure_ascii=False, indent=2))
        return 0
    except Exception as e:
        err = {
            "ok": False,
            "error": str(e),
            "updated_at": now_ts(),
            "updated_at_text": dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        }
        save_json(CACHE_FILE, err)
        print(format_text(err) if args.text else json.dumps(err, ensure_ascii=False, indent=2))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
