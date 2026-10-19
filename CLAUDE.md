# BSX Ltd

Godot 4.7.2, GDScript, typed, tabs. Read README.md for the module rules; in short:

- Each project thread owns one `modules/<id>/`. Change other modules only through their
  owner's thread; use them only through their `api/` and your `module.tres` depends_on.
- Register scenes, menu entries, HUD panels, settings, save sections and screenshot points
  with Core from your bus's `register_module()`. Core and UI never name other modules.
- Gate new player-facing work behind a flag (`Flags.is_on("<module>.<feature>")`).
- Before a PR: `GODOT=<godot> tools/run_tests.sh` and `python3 tools/check_boundaries.py`.
  Add a `module:<id>` label to PRs so the what's new draft groups them.
- Module threads should not need to edit `project.godot`; ask the Core and UI thread if
  you do.
