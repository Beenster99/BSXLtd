extends ModuleTest
## Flags: module gating, CLI parsing, overrides.
##   tools/run_tests.sh core


func run_tests() -> void:
	var saved := Flags.all()

	Flags.use({"trades": true, "trades.bolting": true, "trades.welding": false})
	check(Flags.is_on("trades"), "module flag on")
	check(Flags.is_on("trades.bolting"), "feature on when module on")
	check(not Flags.is_on("trades.welding"), "feature off")
	check(not Flags.is_on("nothing.at_all"), "unknown key is off")
	Flags.set_flag("trades", false)
	check(not Flags.is_on("trades.bolting"), "feature off when its module is off")

	var parsed: Dictionary = Flags.parse_cli(PackedStringArray(
			["--other", "--flags=trades.welding=on,quality=off,business"]))
	check(parsed == {"trades.welding": true, "quality": false, "business": true},
			"CLI flags parse: %s" % parsed)

	var profile := load("res://config/release_profiles/v0.1.tres") as FlagSet
	check(profile != null and profile.flags.get("trades.bolting") == true,
			"v0.1 profile switches bolting on")
	check(not Flags.is_release_build(), "tests are not a release build")

	Flags.use(saved)
