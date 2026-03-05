#!/usr/bin/env python3
"""App Store Connect API - Sales Reporter"""
import jwt
import requests
import time
import gzip
import csv
import os
from datetime import datetime, timezone, timedelta
from zoneinfo import ZoneInfo
from collections import defaultdict

def _load_env_file_if_needed():
    """Best-effort loader for scripts/appstore.env.

    Cron jobs often run with a minimal environment, so we try to source config
    from a repo-local env file if required variables are missing.

    Supports lines like:
      export FOO="bar"
    including multi-line quoted values (used for the private key).
    """
    required = ["APPSTORE_KEY_ID", "APPSTORE_ISSUER_ID", "APPSTORE_PRIVATE_KEY"]
    if all(os.environ.get(k) for k in required):
        return

    env_path = os.environ.get(
        "APPSTORE_ENV_FILE",
        os.path.join(os.path.dirname(__file__), "appstore.env"),
    )
    if not os.path.exists(env_path):
        return

    try:
        with open(env_path, "r", encoding="utf-8") as f:
            lines = f.read().splitlines()

        i = 0
        while i < len(lines):
            line = lines[i].strip()
            i += 1
            if not line or line.startswith("#"):
                continue
            if not line.startswith("export ") or "=" not in line:
                continue

            key, rest = line[len("export "):].split("=", 1)
            key = key.strip()
            rest = rest.strip()

            # Handle quoted values; allow multi-line until closing quote.
            if rest.startswith('"'):
                val = rest[1:]
                while not val.endswith('"') and i < len(lines):
                    val += "\n" + lines[i]
                    i += 1
                if val.endswith('"'):
                    val = val[:-1]
            else:
                val = rest

            # Don't overwrite explicitly provided env
            os.environ.setdefault(key, val)
    except Exception:
        # If parsing fails, we just fall back to current env.
        return


_load_env_file_if_needed()

# Load config from env (after optional env-file load)
APPSTORE_KEY_ID = os.environ.get("APPSTORE_KEY_ID")
APPSTORE_ISSUER_ID = os.environ.get("APPSTORE_ISSUER_ID")
APPSTORE_PRIVATE_KEY = os.environ.get("APPSTORE_PRIVATE_KEY")
VENDOR = os.environ.get("APPSTORE_VENDOR", "93886172")

def get_token():
    missing = [
        k
        for k, v in {
            "APPSTORE_KEY_ID": APPSTORE_KEY_ID,
            "APPSTORE_ISSUER_ID": APPSTORE_ISSUER_ID,
            "APPSTORE_PRIVATE_KEY": APPSTORE_PRIVATE_KEY,
        }.items()
        if not v
    ]
    if missing:
        print(f"ERROR: Missing env vars: {', '.join(missing)}")
        return None

    now = int(time.time())
    return jwt.encode(
        {"iss": APPSTORE_ISSUER_ID, "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"},
        APPSTORE_PRIVATE_KEY,
        algorithm="ES256",
        headers={"kid": APPSTORE_KEY_ID, "typ": "JWT"},
    )

def fetch_sales():
    token = get_token()
    if not token:
        return None

    headers = {"Authorization": f"Bearer {token}", "Accept": "application/a-gzip"}

    # Apple requires an explicit reportDate.
    # Strategy:
    # - If APPSTORE_REPORT_DATE is set, use it.
    # - Otherwise try the most recent few dates (LA time) until one exists.
    forced_report_date = os.environ.get("APPSTORE_REPORT_DATE")

    la_now = datetime.now(ZoneInfo("America/Los_Angeles"))
    candidate_dates = (
        [forced_report_date]
        if forced_report_date
        else [
            (la_now - timedelta(days=1)).date().isoformat(),
            (la_now - timedelta(days=2)).date().isoformat(),
            (la_now - timedelta(days=3)).date().isoformat(),
        ]
    )

    resp = None
    used_report_date = None
    for report_date in candidate_dates:
        params = {
            "filter[vendorNumber]": VENDOR,
            "filter[reportType]": "SALES",
            "filter[reportSubType]": "SUMMARY",
            "filter[frequency]": "DAILY",
            "filter[reportDate]": report_date,
        }

        resp = requests.get(
            "https://api.appstoreconnect.apple.com/v1/salesReports",
            headers=headers,
            params=params,
        )

        if resp.status_code == 200:
            used_report_date = report_date
            break

        # 404 means “no report found for that date” — try the next candidate.
        if resp.status_code == 404 and not forced_report_date:
            continue

        print(f"ERROR: {resp.status_code} - {resp.text[:200]}")
        return None

    if resp is None or resp.status_code != 200:
        # No report available in our lookback window.
        return {"units": 0, "revenue": 0, "products": {}, "report_date": None}

    data = gzip.decompress(resp.content).decode('utf-8')
    lines = data.strip().split('\n')
    
    # Find Jabbit only
    jabbit_rows = [l for l in lines if 'jabbit' in l.lower()]
    
    if not jabbit_rows:
        return {"units": 0, "revenue": 0, "products": {}, "report_date": used_report_date}
    
    # Parse
    by_product = defaultdict(lambda: {"units": 0, "revenue": 0})
    for line in jabbit_rows:
        cols = line.split('\t')
        if len(cols) >= 9:
            title = cols[3]  # Title is index 3
            units = int(cols[7] or 0)
            proceeds = float(cols[8] or 0)
            by_product[title]["units"] += units
            by_product[title]["revenue"] += proceeds
    
    total_units = sum(p["units"] for p in by_product.values())
    total_revenue = sum(p["revenue"] for p in by_product.values())
    
    return {
        "units": total_units,
        "revenue": total_revenue,
        "products": dict(by_product),
        "report_date": used_report_date,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }

if __name__ == "__main__":
    result = fetch_sales()
    if result:
        print(f"📊 App Store Sales Report")
        report_date = result.get('report_date')
        if report_date:
            try:
                # Jon policy: treat lag as zero by default/until explicitly disproven.
                print(f"  Report date (PT): {report_date} (lag: 0 days)")
            except Exception:
                print(f"  Report date (PT): {report_date}")
        else:
            print("  Report date (PT): unavailable")
        print(f"  Units: {result['units']}")
        print(f"  Revenue: ${result['revenue']:.2f}")
        for product, stats in result['products'].items():
            print(f"  {product}: {stats['units']} units, ${stats['revenue']:.2f}")
