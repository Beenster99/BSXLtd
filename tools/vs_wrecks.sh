#!/usr/bin/env bash
# Re-packs Void Salvage's wrecks for BSX from a Void Salvage checkout:
#   tools/vs_wrecks.sh /path/to/void-salvage
# Void Salvage writes every wreck design as a vswreck file (as built, with meshes), then
# vs_wreck_pack.gd turns them into modules/shared_components/data/wrecks/*.vswz + index.json.
set -euo pipefail
VS="${1:?pass a Void Salvage checkout}"
GODOT="${GODOT:-godot}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
"$GODOT" --headless --path "$VS" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$VS" -- --export-wreck=all --meshes --out="$TMP"
rm -f "$HERE"/modules/shared_components/data/wrecks/*.vswz
"$GODOT" --headless --path "$HERE" -s res://modules/shared_components/internal/tools/vs_wreck_pack.gd -- --in="$TMP"
