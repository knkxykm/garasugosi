#!/usr/bin/env python3
"""Download the exact Shippori Mincho Regular used by Garasugoshi. Setup-time only."""
from pathlib import Path
from urllib.request import urlopen
import hashlib

URL = "https://raw.githubusercontent.com/google/fonts/main/ofl/shipporimincho/ShipporiMincho-Regular.ttf"
EXPECTED_SHA256 = "769b5269f0f9bc6534b352c0e6bd856a566e03ff788f107191c2d835863570b2"
DEST = Path(__file__).resolve().parents[1] / "assets/fonts/ShipporiMincho-Regular.ttf"

print("Downloading Shippori Mincho Regular from the official Google Fonts repository…")
data = urlopen(URL, timeout=30).read()
digest = hashlib.sha256(data).hexdigest()
if digest != EXPECTED_SHA256:
    raise SystemExit(f"SHA-256 mismatch: {digest}")
DEST.parent.mkdir(parents=True, exist_ok=True)
DEST.write_bytes(data)
print(f"OK: {DEST} ({len(data):,} bytes)")
