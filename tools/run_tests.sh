#!/usr/bin/env bash
# Runs every module's headless tests (modules/*/tests/test_*.gd), one Godot process each.
# Usage:  GODOT=/path/to/godot tools/run_tests.sh [module ...]
#   tools/run_tests.sh            every module
#   tools/run_tests.sh trades     just one module, while fixing it
set -u
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."

# Class names (ModuleTest, FlagSet, ...) need the import cache; build it once.
if [ ! -d .godot ]; then
	"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
fi

if [ $# -gt 0 ]; then
	files=$(for m in "$@"; do ls modules/"$m"/tests/test_*.gd 2>/dev/null; done)
else
	files=$(ls modules/*/tests/test_*.gd 2>/dev/null)
fi

failed=0
for f in $files; do
	out=$(timeout 300 "$GODOT" --headless --path . res://modules/core/api/testing/test_runner.tscn -- --test="res://$f" 2>&1)
	status=$?
	echo "$out" | grep -v '^Godot Engine' | grep -v '^$'
	# A script error stops the test function without failing a check, so count it too.
	if [ "$status" -ne 0 ] || echo "$out" | grep -q 'SCRIPT ERROR'; then
		echo "FAILED: $f"
		failed=1
	fi
done
[ "$failed" -eq 0 ] && echo "All module tests passed." || echo "Some module tests failed."
exit "$failed"
