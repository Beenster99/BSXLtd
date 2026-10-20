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


class Resettable extends Provider:
	var was_reset := false

	func reset_data() -> void:
		was_reset = true
		data = {}


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
	DirAccess.remove_absolute(Saves.path_for(slot))
	check(Saves.current_slot == "", "loading a slot doesn't make it the current game")

	# Games: new, listed, continued, deleted.
	var r := Resettable.new()
	r.data = {"stock": 40}
	Saves.register_section("test_r", r)
	a.data = {"bolts": 3}
	var game := Saves.new_game("  _Test yard %d " % Time.get_ticks_usec())
	check(r.was_reset and r.data.is_empty(), "a new game calls reset_data()")
	check(a.data.is_empty() and a.loaded_from == 1, "a new game loads empty data without reset_data()")
	check(Saves.current_slot == game and Saves.exists(game), "a new game is written and current")
	check(Saves.current_name.begins_with("_Test yard"), "the name is trimmed")
	var listed := Saves.games().filter(func(g): return g.slot == game)
	check(listed.size() == 1 and listed[0].name == Saves.current_name, "games() lists it by name")
	var plain := "_plain_%d" % Time.get_ticks_usec()
	Saves.current_slot = ""
	Saves.save(plain)
	Saves.current_slot = game
	check(not Saves.games().any(func(g): return g.slot == plain), "plain slots aren't listed as games")
	DirAccess.remove_absolute(Saves.path_for(plain))
	var twin := Saves.new_game(Saves.current_name)
	check(twin != game, "a second game of the same name gets its own slot")
	Saves.delete(twin)
	r.data = {"stock": 7}
	Saves.save(game)
	Saves.close_game()
	check(Saves.current_slot == "", "close_game leaves no game current")
	r.data = {}
	check(Saves.continue_game(game) == OK and r.data.get("stock") == 7, "continue loads the game")
	check(Saves.current_slot == game and Saves.current_name.begins_with("_Test yard"),
			"continue makes it current with its name")
	check(Saves.delete(game) == OK and not Saves.exists(game), "delete removes the file")
	check(Saves.current_slot == "", "deleting the current game clears it")
	check(Saves.delete(game) == ERR_FILE_NOT_FOUND, "deleting twice reports not found")
	Saves.unregister_section("test_r")
	Saves.unregister_section("test_a")
	Saves.unregister_section("test_b")
