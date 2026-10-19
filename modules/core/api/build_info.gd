class_name BuildInfo
extends RefCounted
## The version, commit and date of this build. tools/build/release.sh writes
## res://config/build_info.cfg; without it (the editor, a dev run) the commit reads "dev".

const PATH := "res://config/build_info.cfg"


static func version() -> String:
	return str(_cfg().get_value("build", "version",
			ProjectSettings.get_setting("application/config/version", "0.0.0")))


static func commit() -> String:
	return str(_cfg().get_value("build", "commit", "dev"))


static func label() -> String:
	return "v%s (%s)" % [version(), commit()]


static func _cfg() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	return cfg
