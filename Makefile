# Shortcuts for the scripts in tools/. Set GODOT to your Godot 4.7.2 binary if it isn't on PATH.
GODOT ?= godot
export GODOT

.PHONY: test check release

test:            ## all module tests (MODULES="trades" for one)
	tools/run_tests.sh $(MODULES)

check:           ## module boundary rules
	python3 tools/check_boundaries.py

release:         ## make release VERSION=0.1.0
	@test -n "$(VERSION)" || (echo "usage: make release VERSION=0.1.0" && exit 1)
	tools/build/release.sh $(VERSION)
