extends ModuleTest
## Design Room: the hull built round the rooms (frames, outer and inner walls) and the wires
## and pipes (runs, networks, the router, their rules), on the sample skiff.
##   tools/run_tests.sh design

const Samples := preload("res://modules/design/internal/sample_designs.gd")

var cat := DesignCatalog.load_default()


func run_tests() -> void:
	_structure()
	_runs_and_networks()
	_router()
	_saves()


func _structure() -> void:
	# Two rooms side by side: 4 x 4 and 4 x 4, sharing a 4 m wall.
	var d := DesignRecord.new("t", "Two rooms")
	d.apply({"op": "add_room", "room": {"type": "cargo", "x": 0, "z": 0, "w": 4, "d": 4}})
	d.apply({"op": "add_room", "room": {"type": "cargo", "x": 4, "z": 0, "w": 4, "d": 4}})
	var st := DesignStructure.measure(d)
	check(is_equal_approx(st.inner_len, 4.0), "the shared wall is one 4 m inner wall: %.2f" % st.inner_len)
	check(is_equal_approx(st.outer_len, 24.0), "the outside is 24 m of outer wall: %.2f" % st.outer_len)
	# Outer walls 24 x 3, plus floor and roof 32 m2 each (nothing under or over).
	check(is_equal_approx(st.outer_area, 72.0 + 64.0), "outer hull is walls, floor and roof: %.1f" % st.outer_area)
	check(is_equal_approx(st.frame_m, 24.0 * 3.0 / 2.0 + 32.0 / 2.0), "frame every 2 m: %.1f" % st.frame_m)
	# A room on top covers the roof of the first.
	d.apply({"op": "add_room", "room": {"type": "cargo", "deck": 1, "x": 0, "z": 0, "w": 4, "d": 4}})
	var st2 := DesignStructure.measure(d)
	check(is_equal_approx(st2.outer_area, st.outer_area - 16.0 + 16.0 * 3.0 + 16.0),
			"a room on top: one roof covered, its own walls and roof added: %.1f" % st2.outer_area)

	var t := DesignTotals.compute(d, cat)
	var ids := t.lines.filter(func(l): return l.kind == "hull").map(func(l): return l.id)
	check(ids == ["frame", "hull", "welds", "rivets", "inner", "deck"], "the hull lines come first, with the joints: %s" % [ids])
	var before := t.cost
	d.apply({"op": "set_meta", "fields": {"structure": {"hull": "armoured"}}})
	var t2 := DesignTotals.compute(d, cat)
	check(t2.cost > before and t2.mass > t.mass, "armoured plating costs and weighs more")
	var undo := d.apply({"op": "set_meta", "fields": {"structure": {"frame": "heavy", "spacing": 1.0}}})
	check(d.structure.frame == "heavy" and float(d.structure.spacing) == 1.0 and d.structure.hull == "armoured",
			"structure fields merge: %s" % [d.structure])
	d.apply(undo)
	check(d.structure.frame == "standard" and float(d.structure.spacing) == 2.0, "and undo puts them back")
	check(DesignStructure.next_choice("frame", "heavy") == "light" and float(DesignStructure.next_choice("spacing", 3.0)) == 1.0,
			"choices step round")


func _runs_and_networks() -> void:
	var d := DesignRecord.new("s", "Skiff")
	Samples.skiff(d)
	check(d.runs.is_empty(), "the skiff without the catalogue has no runs")
	var cut := DesignServices.cut_off(d, cat, "wire")
	check(cut.has("c3") and not cut.has("c2"), "the engine needs power, the reactor makes it: %s" % [cut])
	check(not DesignRules.check(d, cat).any(func(p): return p.code == "unpowered"),
			"no wiring at all is not flagged (not wired yet)")
	# A wire from the reactor to the engine (both in engineering).
	var u := d.apply({"op": "add_run", "run": {"kind": "wire", "deck": 0, "points": [[3, 2.5], [5.6, 2.6]]}})
	check(not u.is_empty() and d.runs.size() == 1, "a wire is added")
	var net := DesignServices.connected(d, cat, "wire")
	check(net.components.has("c3"), "the engine is on the reactor's network")
	var probs := DesignRules.check(d, cat)
	var unpowered := probs.filter(func(p): return p.code == "unpowered")
	check(unpowered.size() == 1 and not unpowered[0].components.has("c3") and unpowered[0].components.has("c1"),
			"once wired, what's still cut off is flagged: %s" % [unpowered])
	# A second run touching the first joins it; one far off does not.
	d.apply({"op": "add_run", "run": {"id": "wx", "kind": "wire", "deck": 0, "points": [[4, 2.5], [4, -1.5]]}})
	check(DesignServices.connected(d, cat, "wire").runs.has("wx"), "a run touching another joins it")
	d.apply({"op": "add_run", "run": {"id": "wy", "kind": "wire", "deck": 0, "points": [[-6, -5], [-2, -5]]}})
	check(not DesignServices.connected(d, cat, "wire").runs.has("wy"), "a run off on its own is not live")
	check(d.apply({"op": "add_run", "run": {"kind": "wire", "deck": 0, "points": [[0, 0]]}}).is_empty(),
			"a run needs two points")
	var w_undo := d.apply({"op": "remove_run", "id": "wx"})
	check(not d.runs.has("wx") and not d.apply(w_undo).is_empty() and d.runs.has("wx"), "remove and undo a run")
	var t := DesignTotals.compute(d, cat)
	check(t.lines.any(func(l): return l.kind == "service" and l.id == "wire" and l.qty > 6.0), "wiring is priced per m")


func _router() -> void:
	var d := DesignRecord.new("s", "Skiff")
	Samples.skiff(d, cat)
	check(not d.runs.is_empty(), "the skiff is wired and piped")
	check(DesignServices.cut_off(d, cat, "wire").is_empty(), "every powered part is on a wire: %s"
			% [DesignServices.cut_off(d, cat, "wire")])
	check(DesignServices.cut_off(d, cat, "fuel").is_empty(), "the engine and reactor have fuel lines from the pump: %s"
			% [DesignServices.cut_off(d, cat, "fuel")])
	var decks := {}
	for w: Dictionary in d.runs.values():
		if w.kind == "fuel":
			decks[int(w.deck)] = true
	check(decks.has(0) and decks.has(1), "the fuel line comes down the stairwell from deck 2: %s" % [decks.keys()])
	var probs := DesignRules.check(d, cat)
	check(DesignRules.errors(probs) == 0 and not probs.any(func(p): return p.code in ["unpowered", "no_fuel"]),
			"the sample has no service problems: %s" % [probs.map(func(p): return p.text)])
	check(DesignServices.route(d, cat, "wire").is_empty(), "routing again adds nothing")
	# A ship with no pump: the router can't feed the engine, and says nothing up.
	var e := DesignRecord.new("e", "No pump")
	e.apply({"op": "add_room", "room": {"id": "r1", "type": "engineering", "x": 0, "z": 0, "w": 6, "d": 6}})
	e.apply({"op": "add_component", "component": {"type": "main_engine", "room": "r1", "x": 3, "z": 3}})
	check(DesignServices.route(e, cat, "fuel").is_empty(), "no pump, no fuel route")


func _saves() -> void:
	var d := DesignRecord.new("s", "Skiff")
	Samples.skiff(d, cat)
	d.apply({"op": "set_meta", "fields": {"structure": {"inner": "bulkhead"}}})
	var back := DesignRecord.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	check(back.runs.size() == d.runs.size() and back.structure.inner == "bulkhead",
			"runs and structure survive a save")
	check(JSON.stringify(back.to_dict()) == JSON.stringify(d.to_dict()), "and round-trip exactly")
