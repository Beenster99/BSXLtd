#!/usr/bin/env python3
"""Writes storage_catalogue.json: every part the storage hall keeps a home for.

The parts are the ones BSX can buy (Business's market catalogue, generated from Void
Salvage's part_catalog.gd and design_manifests.json), plus the fasteners and the ship
upgrade modules. Run it again when the market changes:

    python3 modules/ship_bay/internal/storage/make_catalogue.py
"""
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[4]
MARKET = ROOT / "modules/business/internal/data/market_catalogue.tres"
FASTENERS = ROOT / "modules/shared_components/internal/fasteners"
MODULES = ROOT / "modules/shared_components/internal/ship_modules"
OUT = pathlib.Path(__file__).with_name("storage_catalogue.json")
FASTENER_NAMES = {"M10": "M10 bolt", "M12": "M12 bolt", "RIVET_4": "4 mm rivet"}

ROW = re.compile(r'"(\w+)": \{"name": "([^"]*)", "category": "(\w+)", "value": \d+, "mass": ([\d.]+)')


def field(text: str, key: str) -> str:
    m = re.search(r'^%s = "?([^"\n]*)"?$' % key, text, re.M)
    return m.group(1) if m else ""


def main() -> None:
    market = MARKET.read_text()
    items = {}
    for part, name, category, mass in ROW.findall(market):
        items[part] = {"name": name, "category": category, "mass": float(mass)}
    for f in sorted(FASTENERS.glob("*.tres")):
        t = f.read_text()
        fid = field(t, "id")
        if fid:
            items[fid] = {"name": FASTENER_NAMES.get(fid, fid), "category": "fasteners", "mass": 0.05}
    for f in sorted(MODULES.glob("*.tres")):
        t = f.read_text()
        mid = field(t, "id")
        if mid:
            # Upgrade kits come crated; none is listed with a mass yet.
            items[mid] = {"name": field(t, "display_name") or mid, "category": "modules", "mass": 900.0}
    source = field(market, "source_commit")
    OUT.write_text(json.dumps({"void_salvage_commit": source, "items": dict(sorted(items.items()))},
            indent="\t") + "\n")
    print("wrote %d items to %s" % (len(items), OUT))


if __name__ == "__main__":
    main()
