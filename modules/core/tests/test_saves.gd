extends ModuleTest
## Saves: round trip, schema version handed to the provider, sections of switched-off
## modules kept.
##   tools/run_tests.sh core


class Provider:
	var version := 1
	var data := {}
	var loaded_from := -1

	func save_version() -> int:
		return version

	func save_data() -> Dictionary:
		return data

	func load_data(d: Dictionary, from_version: int) -> void:
		data = d
		loaded_from = from_version


func run_tests() -> void:
	var slot := "_test_%d" % Time.get_ticks_usec()
	var a := Provider.new()
	var b := Provider.new()
	a.data = {"bolts": 12}
	b.data = {"cash": 500}
	b.version = 3
	Saves.register_section("test_a", a)
	Saves.register_section("test_b", b)
	check(Saves.save(slot) == OK, "save writes")

	# Module b switched off: its section must survive a load and a re-save.
	Saves.unregister_section("test_b")
	a.data = {}
	check(Saves.load_slot(slot) == OK, "load reads")
	check(a.data.get("bolts") == 12, "provider gets its data back")
	check(a.loaded_from == 1, "provider gets its schema version")
	check(Saves.save(slot) == OK, "re-save with a module off")

	Saves.register_section("test_b", b)
	b.data = {}
	Saves.load_slot(slot)
	check(b.data.get("cash") == 500 and b.loaded_from == 3, "switched-off module's section kept")

	check(Saves.load_slot("_no_such_slot") == ERR_FILE_NOT_FOUND, "missing slot reports not found")
	Saves.unregister_section("test_a")
	Saves.unregister_section("test_b")
	DirAccess.remove_absolute(Saves.path_for(slot))
