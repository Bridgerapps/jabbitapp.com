#!/usr/bin/env python3
"""App Store Connect API - Sales Reporter"""
import jwt
import requests
import time
import gzip
import csv
import io
import os
from datetime import datetime, timezone, timedelta
from zoneinfo import ZoneInfo

def _load_env_file_if_needed():
    """Best-effort loader for ~/.secrets/appstore.env.

    Cron jobs often run with a minimal environment, so we try to source config
    from the out-of-repo secrets file if required variables are missing.
    There is deliberately no repo-local fallback: secrets never live in a repo dir.

    Supports lines like:
      export FOO="bar"
    including multi-line quoted values (used for the private key).
    """
    required = ["APPSTORE_KEY_ID", "APPSTORE_ISSUER_ID", "APPSTORE_PRIVATE_KEY"]
    if all(os.environ.get(k) for k in required):
        return

    # Secrets live outside the repo (mode 600). No repo-local fallback.
    env_path = os.environ.get(
        "APPSTORE_ENV_FILE",
        os.path.expanduser("~/.secrets/appstore.env"),
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

PT = ZoneInfo("America/Los_Angeles")
API = "https://api.appstoreconnect.apple.com/v1/salesReports"

# How Apple's daily Summary Sales report behaves (docs + live probe 2026-10-22):
# - 200 + gzip TSV: a report exists (>=1 unit of any kind that PT day).
# - 404 NOT_FOUND "There were no sales for the date specified.": day closed, nothing sold
#   or downloaded (Apple publishes no file for an empty day).
# - 404 NOT_FOUND "Report is not available yet. Daily reports for the Americas are
#   available by 5 am Pacific Time; ...": the day is not published yet.
# - 410 GONE_ERROR: older than the 365-day retention.
# Docs: reports "generally available by 8 a.m. Pacific Time"; days run 12:00-11:59 PM PT.
# https://developer.apple.com/help/app-store-connect/reference/sales-and-trends-reports-availability/
AVAILABLE_HOUR_PT = 8          # documented "generally available by" hour, day after the report date
PROVISIONAL_HOURS = 24         # a "no sales" answer this soon after the cutoff is treated as provisional

# Product type identifiers:
# https://developer.apple.com/help/app-store-connect/reference/product-type-identifiers/
NEW_DOWNLOAD_TYPES = {"1", "1F", "1T", "F1", "1-B", "F1-B", "1E", "1EP", "1EU"}  # free or paid app (first download)
REDOWNLOAD_TYPES = {"3", "3F", "3T", "F3"}
UPDATE_TYPES = {"7", "7F", "7T", "F7"}


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


def availability_cutoff(report_date: str) -> datetime:
    """Documented availability time for a DAILY report: the next day, 8 AM PT."""
    d = datetime.fromisoformat(report_date).replace(tzinfo=PT)
    return (d + timedelta(days=1)).replace(hour=AVAILABLE_HOUR_PT, minute=0, second=0, microsecond=0)


def classify_day(report_date: str, status_code: int, detail: str, now: datetime) -> str:
    """Return report | no_sales | not_published | expired | error."""
    if status_code == 200:
        return "report"
    d = (detail or "").lower()
    if status_code == 410:
        return "expired"
    if status_code == 404:
        if "not available yet" in d:
            return "not_published"
        if "no sales" in d:
            return "no_sales"
        # Unrecognized 404 text: fall back to the documented availability time.
        return "no_sales" if now >= availability_cutoff(report_date) else "not_published"
    return "error"


def parse_report(text: str) -> dict:
    rows = list(csv.DictReader(io.StringIO(text), delimiter="\t"))
    out = {"downloads": 0, "redownloads": 0, "updates": 0, "iap_units": 0, "other_units": 0,
           "units_all": 0, "proceeds_by_currency": {}, "rows": []}
    title_filter = os.environ.get("APPSTORE_TITLE_FILTER", "jabbit").lower()
    for r in rows:
        if title_filter and title_filter not in (r.get("Title") or "").lower():
            continue
        ptype = (r.get("Product Type Identifier") or "").strip()
        try:
            units = int(float(r.get("Units") or 0))
        except ValueError:
            units = 0
        try:
            per_unit = float(r.get("Developer Proceeds") or 0)
        except ValueError:
            per_unit = 0.0
        cur = (r.get("Currency of Proceeds") or "").strip() or "?"
        out["units_all"] += units
        if ptype in NEW_DOWNLOAD_TYPES:
            out["downloads"] += units
        elif ptype in REDOWNLOAD_TYPES:
            out["redownloads"] += units
        elif ptype in UPDATE_TYPES:
            out["updates"] += units
        elif ptype.startswith("IA") or ptype.startswith("FI"):
            out["iap_units"] += units
        else:
            out["other_units"] += units
        out["proceeds_by_currency"][cur] = round(out["proceeds_by_currency"].get(cur, 0.0) + units * per_unit, 2)
        out["rows"].append({"title": r.get("Title"), "product_type": ptype, "units": units,
                            "country": r.get("Country Code"), "device": r.get("Device")})
    return out


def fetch_day(headers: dict, report_date: str, now: datetime) -> dict:
    params = {
        "filter[vendorNumber]": VENDOR,
        "filter[reportType]": "SALES",
        "filter[reportSubType]": "SUMMARY",
        "filter[frequency]": "DAILY",
        "filter[version]": "1_0",
        "filter[reportDate]": report_date,
    }
    resp = requests.get(API, headers=headers, params=params, timeout=60)
    day = {"date": report_date, "http": resp.status_code}
    detail = ""
    if resp.status_code != 200:
        try:
            errs = resp.json().get("errors") or []
            if errs:
                day["apple_code"] = errs[0].get("code")
                detail = errs[0].get("detail") or ""
                day["apple_detail"] = detail
        except Exception:
            day["apple_detail"] = resp.text[:200]
    day["status"] = classify_day(report_date, resp.status_code, detail, now)
    if day["status"] == "report":
        day.update(parse_report(gzip.decompress(resp.content).decode("utf-8")))
    if day["status"] == "no_sales":
        day["provisional"] = now < availability_cutoff(report_date) + timedelta(hours=PROVISIONAL_HOURS)
    return day


def fetch_sales():
    token = get_token()
    if not token:
        return None
    headers = {"Authorization": f"Bearer {token}", "Accept": "application/a-gzip"}

    now = datetime.now(PT)
    forced = os.environ.get("APPSTORE_REPORT_DATE")
    lookback = int(os.environ.get("APPSTORE_LOOKBACK_DAYS", "3"))
    dates = [forced] if forced else [(now - timedelta(days=i)).date().isoformat() for i in range(0, lookback + 1)]

    days = []
    try:
        for d in dates:
            days.append(fetch_day(headers, d, now))
    except Exception as e:  # network/parse failure
        print(f"ERROR: {type(e).__name__}: {str(e)[:200]}")
        return None

    if any(d["status"] == "error" for d in days):
        bad = next(d for d in days if d["status"] == "error")
        print(f"ERROR: {bad['http']} {bad.get('apple_code', '')} {bad.get('apple_detail', '')[:200]}")
        return None

    # Latest settled day = newest date Apple has closed (report or no_sales).
    settled = next((d for d in days if d["status"] in ("report", "no_sales")), None)
    pending = [d["date"] for d in days if d["status"] == "not_published"]
    result = {
        "days": days,
        "pending_dates": pending,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    if settled is None:
        result.update({"day_status": "not_published", "report_date": None, "units": 0, "revenue": 0.0})
        return result
    proceeds = settled.get("proceeds_by_currency", {})
    result.update({
        "day_status": settled["status"],
        "provisional": bool(settled.get("provisional", False)),
        "report_date": settled["date"],
        "apple_detail": settled.get("apple_detail"),
        "units": settled.get("downloads", 0),
        "units_all": settled.get("units_all", 0),
        "redownloads": settled.get("redownloads", 0),
        "updates": settled.get("updates", 0),
        "iap_units": settled.get("iap_units", 0),
        "revenue": float(proceeds.get("USD", 0.0)),
        "proceeds_by_currency": proceeds,
        "rows": settled.get("rows", []),
    })
    return result


def describe(r: dict) -> str:
    st = r.get("day_status")
    if st == "report":
        return (f"report for {r['report_date']} (PT): {r['units']} new downloads, "
                f"{r.get('redownloads', 0)} re-downloads, {r.get('updates', 0)} updates, "
                f"{r.get('iap_units', 0)} in-app purchase units")
    if st == "no_sales":
        return (f"no sales on {r['report_date']} (PT): Apple says there were no sales"
                + (" (provisional, recently closed day)" if r.get("provisional") else ""))
    return "not published yet: no closed day in the lookback window"


if __name__ == "__main__":
    import argparse
    import json

    ap = argparse.ArgumentParser(description="Fetch Apple App Store Connect Sales (summary daily) report.")
    ap.add_argument("--json", action="store_true", help="Emit machine-readable JSON")
    args = ap.parse_args()

    result = fetch_sales()
    if not result:
        if args.json:
            print(json.dumps({"ok": False, "error": "fetch_failed"}))
        raise SystemExit(1)

    if args.json:
        out = {
            "ok": True,
            "metric": "sales_reports_units",
            "units_definition": "new app downloads (product types 1/1F/1T/F1...); excludes re-downloads (3*), updates (7*) and in-app purchases",
            "summary": describe(result),
        }
        out.update({k: v for k, v in result.items()})
        out["units"] = int(result.get("units") or 0)
        out["revenue_usd"] = float(result.pop("revenue", 0) or 0)
        out.pop("revenue", None)
        print(json.dumps(out, sort_keys=True))
        raise SystemExit(0)

    print("📊 App Store Sales Report")
    report_date = result.get("report_date")
    if report_date:
        print(f"  Report date (PT): {report_date}")
    else:
        print("  Report date (PT): unavailable")
    print(f"  Status: {describe(result)}")
    print(f"  Units: {result['units']}")
    print(f"  Revenue: ${result['revenue']:.2f}")
    for d in result["days"]:
        print(f"  {d['date']}: {d['status']} (HTTP {d['http']})")
