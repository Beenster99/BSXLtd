#!/usr/bin/env bash
# Builds a release: applies the release's flag profile, runs the tests and the boundary
# check, exports Windows, Linux and macOS, zips each one, takes screenshots and drafts the
# what's new summary. Same steps on GitHub Actions (release.yml) and on a laptop.
#
#   GODOT=/path/to/godot tools/build/release.sh 0.1.0
#
# Output: release/v<version>/ with bsx-v<version>-<platform>.zip, screenshots/*.png,
# whats_new.md and manifest.json.
# Env: ALLOW_DIRTY=1 builds from uncommitted changes (local tries only);
#      SKIP_SHOTS=1 skips screenshots; SHOTS_TIMEOUT=<seconds> limits the tour (default 900);
#      PLATFORMS="linux windows" builds a subset.
set -euo pipefail

VERSION="${1:-}"
GODOT="${GODOT:-godot}"
PLATFORMS="${PLATFORMS:-windows linux macos}"
SHOTS_TIMEOUT="${SHOTS_TIMEOUT:-900}"
cd "$(dirname "$0")/../.."
ROOT="$(pwd)"

die() { echo "release: $*" >&2; exit 1; }
step() { echo; echo "== $*"; }

# 1. Check -------------------------------------------------------------------------------
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "usage: release.sh <major.minor.patch>"
MINOR="${VERSION%.*}"
PROFILE="config/release_profiles/v${MINOR}.tres"
[ -f "$PROFILE" ] || die "no flag profile $PROFILE for this release"
if [ "${ALLOW_DIRTY:-0}" != "1" ] && [ -n "$(git status --porcelain)" ]; then
	die "working tree has uncommitted changes (ALLOW_DIRTY=1 to build anyway)"
fi
if [ "${GITHUB_REF_TYPE:-}" = "tag" ] && [ "${GITHUB_REF_NAME:-}" != "v$VERSION" ]; then
	die "tag ${GITHUB_REF_NAME} does not match version $VERSION"
fi
COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
OUT="release/v$VERSION"
rm -rf "$OUT" release/export
mkdir -p "$OUT/screenshots"

# 2. Apply flags and stamp the build (put back afterwards so a local tree stays clean) ------
step "Applying $PROFILE"
cp config/project_flags.tres "$ROOT/release/.project_flags.backup"
restore() {
	cp "$ROOT/release/.project_flags.backup" "$ROOT/config/project_flags.tres"
	rm -f "$ROOT/release/.project_flags.backup" "$ROOT/config/build_info.cfg"
}
trap restore EXIT
cp "$PROFILE" config/project_flags.tres
cat > config/build_info.cfg <<CFG
[build]

version="$VERSION"
commit="$COMMIT"
date="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
CFG

# 3. Test ----------------------------------------------------------------------------------
step "Importing"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
step "Module tests"
GODOT="$GODOT" tools/run_tests.sh
step "Module boundaries"
python3 tools/check_boundaries.py

# 4 and 5. Export and zip -------------------------------------------------------------------
preset_for() {
	case "$1" in
		windows) echo "Windows Desktop" ;;
		linux) echo "Linux" ;;
		macos) echo "macOS" ;;
		*) die "unknown platform $1" ;;
	esac
}
for platform in $PLATFORMS; do
	preset="$(preset_for "$platform")"
	step "Exporting $preset"
	mkdir -p "release/export/$platform"
	"$GODOT" --headless --path . --export-release "$preset" 2>&1 | grep -vE '^\s*$' | tail -n 20
	zip="$OUT/bsx-v$VERSION-$platform.zip"
	if [ "$platform" = "macos" ]; then
		# Godot already packs the .app into a zip.
		[ -f release/export/macos/BSXLtd.zip ] || die "macOS export produced nothing"
		mv release/export/macos/BSXLtd.zip "$zip"
	else
		[ -n "$(ls -A "release/export/$platform")" ] || die "$preset export produced nothing"
		(cd "release/export/$platform" && zip -qr "$ROOT/$zip" .)
	fi
	echo "-> $zip"
done

# 5b. Check the packaged data ------------------------------------------------------------------
# Export can drop data a resource holds (0.3.18 lost every Packed*Array left at its `= []`
# default), so compare the arrays the source tree and the Windows build load.
if [[ " $PLATFORMS " == *" windows "* ]]; then
	step "Checking the packaged data"
	PROBE="$ROOT/tools/build/pack_probe.gd"
	"$GODOT" --headless --path . -s "$PROBE" -- "--out=$ROOT/release/probe_source.json" | grep pack_probe
	"$GODOT" --headless --main-pack release/export/windows/BSXLtd.exe -s "$PROBE" \
		-- "--out=$ROOT/release/probe_pack.json" | grep pack_probe
	python3 - release/probe_source.json release/probe_pack.json <<'PY' || die "the packaged build lost data (above)"
import json, sys
src, pack = (json.load(open(p)) for p in sys.argv[1:])
bad = [k for k, n in src.items() if pack.get(k) != n]
for k in bad:
	print(f"  {k}: {src[k]} in the project, {pack.get(k, 'absent')} in the build")
print(f"{len(src)} entries checked, {len(bad)} differ")
sys.exit(1 if bad else 0)
PY
fi

# 6. Screenshots -----------------------------------------------------------------------------
if [ "${SKIP_SHOTS:-0}" = "1" ]; then
	echo "Skipping screenshots (SKIP_SHOTS=1)."
else
	step "Screenshot tour"
	TOUR=("$GODOT" --path . --rendering-driver opengl3
		res://tools/screenshot_tour/screenshot_tour.tscn -- "--out=$ROOT/$OUT/screenshots")
	if [ -n "${DISPLAY:-}" ]; then
		timeout "$SHOTS_TIMEOUT" "${TOUR[@]}"
	elif command -v xvfb-run >/dev/null; then
		timeout "$SHOTS_TIMEOUT" xvfb-run -a -s "-screen 0 1920x1080x24" "${TOUR[@]}"
	else
		die "screenshots need a display or xvfb-run (SKIP_SHOTS=1 to skip)"
	fi
fi

# 7. What's new and manifest -------------------------------------------------------------------
step "What's new draft"
python3 tools/build/whats_new.py --version "$VERSION" --out "$OUT/whats_new.md"

python3 - "$OUT" "$VERSION" "$COMMIT" "$PROFILE" <<'PY'
import hashlib, json, re, sys
from pathlib import Path
out, version, commit, profile = sys.argv[1:]
text = Path(profile).read_text()
flags = {k: v == "true" for k, v in re.findall(r'"([^"]+)":\s*(true|false)', text)}
files = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(Path(out).glob("*.zip"))}
shots = sorted(p.name for p in Path(out, "screenshots").glob("*.png"))
manifest = {"version": version, "commit": commit, "flags": flags, "zips": files, "screenshots": shots}
Path(out, "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
PY

step "Done: $OUT"
ls -la "$OUT" "$OUT/screenshots"
