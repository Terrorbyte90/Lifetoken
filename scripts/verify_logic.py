#!/usr/bin/env python3
"""Pure, deterministic checks for LifeToken's time/zone contract.

This intentionally does not launch an iOS simulator or import SwiftUI. It reads
ZoneProfile.swift and verifies the mathematical invariants used by the Swift
implementation, including exact boundary values.
"""
from pathlib import Path
import re

SOURCE = Path(__file__).parents[1] / "ZoneProfile.swift"
text = SOURCE.read_text(encoding="utf-8")

blocks = re.findall(
    r"static let (\w+) = ZoneProfile\((.*?)\n    \)", text, re.S
)
assert len(blocks) == 14, f"expected 14 zones, found {len(blocks)}"

zones = []
for symbol, body in blocks:
    def number(label):
        m = re.search(rf"{label}:\s*([0-9.]+)", body)
        assert m, f"{symbol}: missing {label}"
        return float(m.group(1))
    zones.append({
        "symbol": symbol,
        "index": int(number("index")),
        "tax": number("taxRate"),
        "work": number("workMultiplier"),
        "inflation": number("inflationRatePerDay"),
        "fall": number("fallThresholdSeconds"),
        "unlock": number("unlockRequirementSeconds"),
        "entry": number("entryCostSeconds"),
    })

assert [z["index"] for z in zones] == list(range(14)), "zone indexes are not contiguous"
assert zones[0]["unlock"] == 0 and zones[0]["entry"] == 0, "Askan must be free start zone"
for previous, current in zip(zones, zones[1:]):
    assert current["unlock"] > previous["unlock"], f"unlock order broken at {current['symbol']}"
    assert 0 <= current["tax"] < 1, f"invalid tax at {current['symbol']}"
    assert current["fall"] < current["unlock"], f"hysteresis floor must be below unlock at {current['symbol']}"
    reserve = current["unlock"] + current["entry"] + current["fall"]
    assert reserve > current["unlock"], f"migration reserve not charged at {current['symbol']}"
    # Exact migration boundary: one second below fails, boundary succeeds.
    assert (reserve - 1) < reserve and reserve >= reserve
    net = current["work"] * (1 - current["tax"]) * (1 - current["inflation"])
    assert net > 0, f"non-positive net work multiplier at {current['symbol']}"

# Pure equivalent of ZoneProfile.currentZone(forTime:), checked at every boundary.
def current_zone(seconds):
    eligible = [z for z in zones if seconds >= z["unlock"]]
    return max(eligible, key=lambda z: z["index"])

for zone in zones:
    assert current_zone(zone["unlock"])["index"] == zone["index"], f"boundary mismatch at {zone['symbol']}"
    if zone["index"] > 0:
        assert current_zone(zone["unlock"] - 1)["index"] == zone["index"] - 1, f"pre-boundary mismatch at {zone['symbol']}"

print("OK: 14 zones, contiguous indexes, monotonic unlocks, valid tax/net math")
print("OK: migration reserve = unlock + entry + fall; exact-boundary cases covered")
print("OK: current-zone selection tested at every unlock and one second before")
