extends Node
## Feature flags (autoload `Flags`). Code asks `Flags.is_on("trades.welding")`; a module whose
## flag is off never registers anything, so players never see it.
##
## Editor and debug builds also read user://flags_override.cfg ([flags] key=true/false) and a
## `-- --flags=trades.welding=on,quality=off` command-line option. Release builds carry the
## `bsx_release` export feature and ignore both, so a release is exactly its profile.

signal changed

const PROJECT_FLAGS := "res://config/project_flags.tres"
const OVERRIDE_PATH := "user://flags_override.cfg"
const RELEASE_FEATURE := "bsx_release"

var _flags: Dictionary = {}


func _init() -> void:
	reload()


## Reloads the project flags and, outside release builds, the overrides.
func reload() -> void:
	_flags = {}
	var set := load(PROJECT_FLAGS) as FlagSet
	if set:
		_flags = set.flags.duplicate()
	else:
		push_warning("Flags: %s missing; everything is off" % PROJECT_FLAGS)
	if not is_release_build():
		_apply_override_file(OVERRIDE_PATH)
		_flags.merge(parse_cli(OS.get_cmdline_user_args()), true)
	changed.emit()


func is_on(key: String) -> bool:
	if not bool(_flags.get(key, false)):
		return false
	var dot := key.find(".")
	return dot < 0 or bool(_flags.get(key.substr(0, dot), false))


## Sets a flag at runtime (tests and the dev console). Not saved.
func set_flag(key: String, on: bool) -> void:
	_flags[key] = on
	changed.emit()


## Replaces every flag (tests).
func use(flags: Dictionary) -> void:
	_flags = flags.duplicate()
	changed.emit()


func all() -> Dictionary:
	return _flags.duplicate()


static func is_release_build() -> bool:
	return OS.has_feature(RELEASE_FEATURE)


## `--flags=a=on,b=off,c` -> {a: true, b: false, c: true}.
static func parse_cli(args: PackedStringArray) -> Dictionary:
	var out := {}
	for arg in args:
		if not arg.begins_with("--flags="):
			continue
		for part in arg.trim_prefix("--flags=").split(",", false):
			var kv := part.split("=")
			var value := kv[1].to_lower() if kv.size() > 1 else "on"
			out[kv[0].strip_edges()] = value in ["on", "true", "1", "yes"]
	return out


func _apply_override_file(path: String) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK or not cfg.has_section("flags"):
		return
	for key in cfg.get_section_keys("flags"):
		_flags[key] = bool(cfg.get_value("flags", key))
