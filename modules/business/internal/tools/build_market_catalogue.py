#!/usr/bin/env python3
"""Builds the Business market's parts list from a Void Salvage checkout.

Reads Void Salvage's PartCatalog (scripts/salvage/part_catalog.gd: names, categories,
blurbs, the same name rules) and its measured design manifests (data/design_manifests.json:
what each part weighs and is worth when built clean), and writes
modules/business/internal/data/market_catalogue.tres: one entry per part a ship yard would
buy, keyed by Void Salvage's part_name so contracts, Shared Components and the market agree.

  python3 modules/business/internal/tools/build_market_catalogue.py <void-salvage checkout>

Every named PartCatalog entry is listed, plus any other part found in at least MIN_DESIGNS
designs (plates, joists, looms, fittings). Value is the median per-unit value across the
designs that carry the part; the market applies trade discounts and condition on top.
"""
import json
import re
import statistics
import subprocess
import sys
from pathlib import Path

MIN_DESIGNS = 4
OUT = Path(__file__).resolve().parents[1] / "data" / "market_catalogue.tres"
KINDS = ["HULL", "FRAME", "HAZARD", "CONDUIT", "COMPONENT", "GLASS"]


def gd_list(src: str, const: str) -> list:
    body = re.search(r"const %s[^=]*=\s*\[(.*?)\]\n" % const, src, re.S).group(1)
    return re.findall(r'"([^"]+)"', body)


def main() -> int:
    vs = Path(sys.argv[1] if len(sys.argv) > 1 else "../void-salvage")
    src = (vs / "scripts/salvage/part_catalog.gd").read_text(encoding="utf-8")
    entries_src = src[src.index("const ENTRIES"):src.index("const FITTINGS")]
    entries = {}
    for m in re.finditer(r'"(\w+)": \{"name": "([^"]+)", "category": "(\w+)"(.*?)\}', entries_src, re.S):
        blurb = re.search(r'"blurb": "((?:[^"\\]|\\.)*)"', m.group(4))
        entries[m.group(1)] = {"name": m.group(2), "category": m.group(3),
                               "blurb": blurb.group(1) if blurb else ""}
    fittings = gd_list(src, "FITTINGS")
    not_fittings = gd_list(src, "NOT_FITTINGS")
    words = [(cat, re.findall(r'"([^"]+)"', ws))
             for cat, ws in re.findall(r'\["(\w+)", \[(.*?)\]\]', src[src.index("const WORDS"):], re.S)]

    def is_fittings(name: str) -> bool:
        return not any(w in name for w in not_fittings) and any(w in name for w in fittings)

    def category(name: str, kind: str) -> str:
        if name in entries:
            return entries[name]["category"]
        fixed = {"HULL": "hull", "FRAME": "frame", "GLASS": "glass", "HAZARD": "fluids"}
        if kind in fixed:
            return fixed[kind]
        if kind == "CONDUIT":
            return "piping" if "Pipe" in name or "Line" in name else "wiring"
        if is_fittings(name):
            return "fittings"
        for cat, ws in words:
            if any(w in name for w in ws):
                return cat
        return "electronics"

    def display(name: str) -> str:
        if name in entries:
            return entries[name]["name"]
        out = ""
        for i, ch in enumerate(name):
            nxt_lower = i + 1 < len(name) and name[i + 1].islower()
            out += (" " + ch.lower()) if i > 0 and ch.isupper() and nxt_lower else ch
        return out

    seen = {}
    for parts in json.loads((vs / "data/design_manifests.json").read_text()).values():
        for name, v in parts.items():
            if v["count"] > 0:
                seen.setdefault(name, []).append((v["value"] / v["count"], v["kg"] / v["count"], v["kind"]))
    rows = []
    for name in sorted(seen):
        if name not in entries and len(seen[name]) < MIN_DESIGNS:
            continue
        kind = KINDS[statistics.mode(k for _, _, k in seen[name])]
        value = max(1, round(statistics.median(v for v, _, _ in seen[name])))
        mass = round(statistics.median(m for _, m, _ in seen[name]), 1)
        rows.append((name, display(name), category(name, kind), value, mass,
                     entries.get(name, {}).get("blurb", "")))
    commit = subprocess.run(["git", "-C", str(vs), "rev-parse", "HEAD"], capture_output=True,
                            text=True).stdout.strip()

    def q(s: str) -> str:
        return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'

    lines = ["{"]
    for i, (name, disp, cat, value, mass, blurb) in enumerate(rows):
        comma = "," if i < len(rows) - 1 else ""
        lines.append('%s: {"name": %s, "category": %s, "value": %d, "mass": %s, "blurb": %s}%s'
                     % (q(name), q(disp), q(cat), value, mass, q(blurb), comma))
    lines.append("}")
    OUT.write_text("""[gd_resource type="Resource" script_class="MarketCatalogue" load_steps=2 format=3]

[ext_resource type="Script" path="res://modules/business/api/market_catalogue.gd" id="1"]

[resource]
script = ExtResource("1")
version = 1
source_commit = %s
parts = %s
""" % (q(commit), "\n".join(lines)), encoding="utf-8")
    print(f"{len(rows)} parts from Void Salvage {commit[:7]} -> {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
