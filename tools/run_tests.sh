#!/usr/bin/env bash
# Runs every module's headless tests (modules/*/tests/test_*.gd), one Godot process each,
# JOBS at a time (default: the number of CPUs, at most 4). Each process gets its own user://
# folder, so tests that save settings or files never share them.
# Usage:  GODOT=/path/to/godot [JOBS=4] tools/run_tests.sh [module ...]
#   tools/run_tests.sh            every module
#   tools/run_tests.sh trades     just one module, while fixing it
#   JOBS=1 tools/run_tests.sh     one at a time, like before
set -u
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."

if [ -z "${JOBS:-}" ]; then
	JOBS=$(nproc 2>/dev/null || echo 1)
	[ "$JOBS" -gt 4 ] && JOBS=4
fi

# Class names (ModuleTest, FlagSet, ...) need the import cache; build it once.
if [ ! -d .godot ]; then
	"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
fi

if [ $# -gt 0 ]; then
	files=$(for m in "$@"; do ls modules/"$m"/tests/test_*.gd 2>/dev/null; done)
else
	files=$(ls modules/*/tests/test_*.gd 2>/dev/null)
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# One test file: its output goes to <n>.log and its exit status to <n>.status.
run_one() {
	local n="$1" f="$2" home
	home="$work/home_$n"
	mkdir -p "$home/data" "$home/cache" "$home/config"
	XDG_DATA_HOME="$home/data" XDG_CACHE_HOME="$home/cache" XDG_CONFIG_HOME="$home/config" \
		timeout 300 "$GODOT" --headless --path . res://modules/core/api/testing/test_runner.tscn \
		-- --test="res://$f" >"$work/$n.log" 2>&1
	echo $? >"$work/$n.status"
	rm -rf "$home"
}
export -f run_one
export GODOT work

n=0
for f in $files; do
	n=$((n + 1))
	printf '%s\t%s\n' "$n" "$f"
done >"$work/list"

# Each line is "<n>\t<file>"; xargs runs JOBS of them at once.
tr '\t' '\n' <"$work/list" | xargs -d '\n' -n 2 -P "$JOBS" bash -c 'run_one "$1" "$2"' _

# Print each file's output in order, with the same checks as before.
failed=0
while IFS=$'\t' read -r n f; do
	out=$(cat "$work/$n.log" 2>/dev/null)
	status=$(cat "$work/$n.status" 2>/dev/null || echo 1)
	echo "$out" | grep -v '^Godot Engine' | grep -v '^$'
	# A script error stops the test function without failing a check, so count it too.
	if [ "$status" -ne 0 ] || echo "$out" | grep -q 'SCRIPT ERROR'; then
		echo "FAILED: $f"
		failed=1
	fi
done <"$work/list"
[ "$failed" -eq 0 ] && echo "All module tests passed." || echo "Some module tests failed."
exit "$failed"
