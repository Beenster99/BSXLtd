# BSX Ltd

A co-op Godot game about running BSX Ltd, the contractor that fits and maintains the salvage
ships of [Void Salvage](https://github.com/dantheo999/void-salvage). Players there send
upgrade contracts; crews here bolt, rivet, weld and wire the work.

Godot **4.7.2** (standard build, not .NET), GDScript, Jolt physics: the same as Void Salvage.

## Running it

1. Install Godot 4.7.2 and open this folder as a project.
2. Press Play. The main menu shows whatever the current flags switch on.

## Layout

```
modules/<id>/          one folder per module, one project thread per module
  api/                 the only part other modules may use (bus script, public classes)
  internal/            everything else; change freely in a fix
  tests/               test_*.gd, run headless
  module.tres          id, depends_on, flag, bus script
addons/ship_components/  the component library shared with Void Salvage (submodule, to come)
config/project_flags.tres        the active feature flags
config/release_profiles/v0.1.tres what each release switches on
tools/run_tests.sh               every module's tests
tools/check_boundaries.py        the module dependency rules
tools/build/release.sh           the release build
tools/screenshot_tour/           release screenshots
```

Modules: core and ui (the shell), contracts, ship_bay, trades, quality, multiplayer,
business, progression. Dependencies point one way (see each `module.tres`).

## Module rules

1. Use another module only through its `api/` folder, and only if it is in your
   `module.tres` `depends_on`. Everyone may use `core/api` and `ui/api`. Core never uses UI.
   CI enforces this with `tools/check_boundaries.py` (paths and class names).
2. Talk through buses: a module's bus node is `Modules.bus("<id>")`, with signals such as
   `joint_completed(joint_id, quality)`. Never reach into another module's scenes.
3. Register with Core instead of being referenced by it:
   `Router.register_scene`, `Menu.register_entry`, `Hud.register_panel`,
   `Settings.register`, `Saves.register_section`, `Shots.register`. Do this in your bus's
   `register_module()`.
4. Save data is one section per module with its own schema version; migrate old versions
   in your provider's `load_data(data, from_version)`.
5. Data lives in `.tres` resources with a `version` field; code reads data.
6. A module whose flag is off (or whose dependency is off) never loads, so its menus, HUD
   panels and scenes simply don't appear.
7. Work on `module/<id>` branches and merge to `main` behind the module's flag.

## Feature flags

`Flags.is_on("trades.welding")`. A key is a module (`trades`) or a feature in one
(`trades.welding`); a feature is on only when its module is on. `config/project_flags.tres`
holds the current release's set. To try something switched off, outside release builds:

- run with `-- --flags=trades.welding=on,quality=on`, or
- put `[flags]` / `trades.welding=true` in `user://flags_override.cfg`.

Release builds (the `bsx_release` export feature) ignore both.

## Tests

```
GODOT=/path/to/godot tools/run_tests.sh          # everything
GODOT=/path/to/godot tools/run_tests.sh trades   # one module
python3 tools/check_boundaries.py
```

A test is `modules/<id>/tests/test_<thing>.gd` extending `ModuleTest`: override
`run_tests()` and call `check(ok, "what")`. It runs inside a normal scene, so autoloads are
ready.

## Releases

1. Merge what's ready, make sure `config/release_profiles/v<major.minor>.tres` switches on
   what this release exposes, and push a tag `v0.1.0`.
2. GitHub Actions (`release.yml`) runs `tools/build/release.sh`: tests, boundary check,
   Windows/Linux/macOS exports zipped as `bsx-v0.1.0-<platform>.zip`, screenshots from
   the tour, a what's new draft from merged PRs (grouped by `module:<id>` labels) and
   `manifest.json`. They land in a draft GitHub Release.
3. Edit the what's new draft; the Release thread posts the zips, summary and screenshots.

Local build: `make release VERSION=0.1.0` (needs Godot export templates for 4.7.2, and
`xvfb-run` or a display for screenshots; `SKIP_SHOTS=1` to skip them).

macOS builds are ad-hoc signed, not notarised: the first time, right-click the app and
choose Open.
