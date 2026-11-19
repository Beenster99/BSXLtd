extends ModuleTest
## Design Room: will she fit the build berth? (DesignBerth): her length, beam and height with
## clearance for the bots against the berth the yard gives, a WILL IT WORK error when not, and
## NEEDS A LARGER BERTH on the contract fit.
##   tools/run_tests.sh design


func ship(length: float, decks := 1) -> DesignRecord:
	var d := DesignRecord.new("b", "Berth test")
	d.apply({"op": "add_room", "room": {"id": "r1", "type": "cargo", "x": 0, "z": 0, "w": 10, "d": length}})
	for i in range(1, decks):
		d.apply({"op": "add_room", "room": {"id": "u%d" % i, "type": "cargo", "x": 0, "z": 0, "w": 10, "d": 4, "deck": i}})
	return d


func run_tests() -> void:
	var small := DesignBerth.fit(ship(20.0), DesignBerth.DEFAULT)
	check(small.ok and is_equal_approx(small.length, 20.0) and is_equal_approx(small.beam, 10.0),
			"a 20 m ship fits the default berth: %s" % [small])
	var long := DesignBerth.fit(ship(58.0), DesignBerth.DEFAULT)
	check(not long.ok and long.over == ["length"], "58 m plus 2 m each side is too long for 60 m: %s" % [long.over])
	check(not DesignBerth.problem(long).is_empty() and DesignBerth.problem(small).is_empty(),
			"only the one that will not fit gets a problem")
	var tall := DesignBerth.fit(ship(10.0, 2), {"name": "Small berth", "length": 40.0, "beam": 20.0, "height": 6.0})
	check(not tall.ok and "height" in tall.over, "two decks are too tall for a 6 m berth")
	# What the yard may give: a dictionary, a Vector3 (beam, height, length) or an AABB.
	check(DesignBerth.from_yard(Vector3(40, 35, 120)).length == 120.0, "a Vector3 berth reads as beam, height, length")
	var ab := DesignBerth.from_yard(AABB(Vector3.ZERO, Vector3(90, 30, 40)), "Berth 1")
	check(ab.length == 90.0 and ab.beam == 40.0 and ab.name == "Berth 1", "an AABB's longest flat side is the length")
	check(DesignBerth.from_yard(null).length == 60.0, "nothing from the yard: the default 60 x 30 x 30")
	# On the bus: WILL IT WORK and the contract fit.
	var bus := Modules.bus("design") as DesignBus
	bus.library.reset_data()
	bus.library.create("Big one")
	var rec := bus.library.current
	bus.editor.do({"op": "add_room", "room": {"id": "r1", "type": "cargo", "x": 0, "z": 0, "w": 10, "d": 30}})
	bus.berth_override = {"name": "Starter berth", "length": 30.0, "beam": 20.0, "height": 20.0}
	bus.editor.do({"op": "set_meta", "fields": {"name": "Big one"}})
	var probs := bus.problems()
	check(probs.any(func(p: Dictionary) -> bool: return p.code == "berth"), "WILL IT WORK flags a ship too big for the berth")
	bus.berth_override = {"name": "Max berth", "length": 300.0, "beam": 120.0, "height": 120.0}
	bus.editor.do({"op": "set_meta", "fields": {"name": "Big one again"}})
	check(not bus.problems().any(func(p: Dictionary) -> bool: return p.code == "berth"), "a bigger berth clears it")
	check(rec != null, "a design was open")
	bus.berth_override = {"name": "Starter berth", "tier": 1, "length": 60.0, "beam": 30.0, "height": 30.0}
	rec.order = {"id": "o", "berth": 3}
	check(bus.order_needs_larger_berth(), "an order wanting tier 3 needs a larger berth than tier 1")
	rec.order = {"id": "o", "berth": 1}
	check(not bus.order_needs_larger_berth(), "a tier 1 order fits tier 1")
	rec.order = {}
	bus.berth_override = {}
