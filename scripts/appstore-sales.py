#!/usr/bin/env python3
"""App Store Connect API - Sales Reporter"""
import jwt
import requests
import time
import gzip
import csv
import os
from datetime import datetime, timezone, timedelta
from collections import defaultdict

# Load config from env
APPSTORE_KEY_ID = os.environ.get("APPSTORE_KEY_ID")
APPSTORE_ISSUER_ID = os.environ.get("APPSTORE_ISSUER_ID")
APPSTORE_PRIVATE_KEY = os.environ.get("APPSTORE_PRIVATE_KEY")
VENDOR = os.environ.get("APPSTORE_VENDOR", "93886172")

def get_token():
    with open("/tmp/appstore_key.p8", "w") as f:
        f.write(APPSTORE_PRIVATE_KEY)
    
    now = int(time.time())
    return jwt.encode(
        {"iss": APPSTORE_ISSUER_ID, "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"},
        APPSTORE_PRIVATE_KEY, algorithm="ES256", 
        headers={"kid": APPSTORE_KEY_ID, "typ": "JWT"}
    )

def fetch_sales():
    token = get_token()
    headers = {"Authorization": f"Bearer {token}", "Accept": "application/a-gzip"}
    
    params = {
        "filter[vendorNumber]": VENDOR,
        "filter[reportType]": "SALES",
        "filter[reportSubType]": "SUMMARY", 
        "filter[frequency]": "DAILY",
    }
    
    resp = requests.get("https://api.appstoreconnect.apple.com/v1/salesReports", 
                       headers=headers, params=params)
    
    if resp.status_code != 200:
        print(f"ERROR: {resp.status_code} - {resp.text[:200]}")
        return None
    
    data = gzip.decompress(resp.content).decode('utf-8')
    lines = data.strip().split('\n')
    
    # Find Jabbit only
    jabbit_rows = [l for l in lines if 'jabbit' in l.lower()]
    
    if not jabbit_rows:
        return {"units": 0, "revenue": 0, "products": {}}
    
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
        "timestamp": datetime.now(timezone.utc).isoformat()
    }

if __name__ == "__main__":
    result = fetch_sales()
    if result:
        print(f"📊 App Store Sales Report")
        print(f"  Units: {result['units']}")
        print(f"  Revenue: ${result['revenue']:.2f}")
        for product, stats in result['products'].items():
            print(f"  {product}: {stats['units']} units, ${stats['revenue']:.2f}")
