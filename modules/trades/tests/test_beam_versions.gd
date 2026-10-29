extends ModuleTest
## trades.beam_versions (beenster, 0.3.27, stage D2 of the beam plan): a ship's beam design keeps
## up to three versions side by side, A, B and C. R shows the next, Shift+R copies the one
## showing into the next; each keeps its own beams and undo starts afresh on a switch. H (TEST)
## checks the one showing: every end held, no clashes, the mass it adds and how far it moves the
## ship's centre of mass (from the ship file's parts). Versions are kept in the save, a save from
## before versions loads as A, and the switch travels in the designer's event.

const FAKE_YARD := """extends Node3D
var walker: CharacterBody3D
var walker_active := true
func set_walker_active(on: bool) -> void:
	walker_active = on
"""


func run_tests() -> void:
	var ship_bus := Modules.bus("ship_bay") as ShipBayBus
	var bus := Modules.bus("trades") as TradesBus
	var saved := {}
	for flag: String in ["trades.beam_designer", "trades.beam_versions"]:
		saved[flag] = Flags.is_on(flag)
		Flags.set_flag(flag, true)
	# Drawn end to end, the first way (trades.beam_grow, growing out of the ship, is test_beam_grow's).
	saved["trades.beam_grow"] = Flags.is_on("trades.beam_grow")
	Flags.set_flag("trades.beam_grow", false)
	# Every stocked section (trades.one_section keeps the tablet to 100 x 100 x 5: test_beam_grow).
	saved["trades.one_section"] = Flags.is_on("trades.one_section")
	Flags.set_flag("trades.one_section", false)
	bus.reset_data()

	# The bus keeps versions.
	var row := {"id": 1, "a": [0.0, 9.0, 0.0], "b": [2.0, 9.0, 0.0], "section": "box_100x100x5", "turn": 0.0}
	bus.set_beam_design("s", [row])
	check(bus.beam_version("s") == "A" and bus.beam_design("s").size() == 1, "a design starts as version A")
	bus.set_beam_design("s", [row, row], "B")
	check(bus.beam_design("s").size() == 1 and bus.beam_design("s", "B").size() == 2, "B is kept beside A")
	bus.show_beam_version("s", "B")
	check(bus.beam_version("s") == "B" and bus.beam_design("s").size() == 2, "showing B")
	var data := JSON.parse_string(JSON.stringify(bus.save_data())) as Dictionary
	bus.reset_data()
	bus.load_data(data, bus.save_version())
	check(bus.beam_version("s") == "B" and bus.beam_design("s", "A").size() == 1 and bus.beam_design("s", "B").size() == 2,
			"versions and the one showing are kept in the save")
	bus.load_data({"templates": [], "beam_designs": {"old": [row]}}, bus.save_version())
	check(bus.beam_version("old") == "A" and bus.beam_design("old").size() == 1, "a save from before versions loads as A")
	bus.reset_data()

	# The mass of the ship from its file.
	ship_bus.load_ship("vs_kestrel")
	var mass := TradesBeamDesigner.ship_mass(ship_bus.ship)
	check(float(mass.get("kg", 0.0)) > 5000.0, "the Kestrel weighs from its file's parts: %.0f kg" % float(mass.get("kg", 0.0)))
	check(ship_bus.ship.bounds.grow(0.5).has_point(mass.get("centre", Vector3.INF)), "its centre of mass is inside it: %s" % [mass.get("centre")])

	var yard := _fake_yard()
	var walker := CharacterBody3D.new()
	walker.position = Vector3(3, 0, 12)
	yard.set("walker", walker)
	yard.add_child(walker)
	add_child(yard)
	bus._on_shipyard_ready(yard)
	await frames(2)
	var rig: TradesBay = yard.get_node(TradesBus.YARD_RIG)
	if rig.designer == null:
		rig.build_designer()
	var d := rig.designer
	var ship := d.ship_id()
	rig.set_tool(&"tablet")
	var y := ship_bus.ship.bounds.end.y + 3.0

	# Two beams meeting at a corner in A, nothing holding their far ends.
	d.add_beam(Vector3(-1, y, 0), Vector3(1, y, 0))
	d.add_beam(Vector3(1, y, 0), Vector3(1, y, 2))
	check(d.version() == "A" and d.beams().size() == 2, "two beams in A")
	var res := d.test()
	check(not bool(res.passed) and int(res.loose) == 2 and int(res.clashes) == 0, "TEST: two loose ends, no clashes: %s" % d.test_line())
	var kg := float(res.kg)
	check(absf(kg - TradesBeamSections.mass("box_100x100x5", 2.0) * 2.0) < 0.1, "TEST weighs what it adds: %.1f kg" % kg)
	var shift: Vector3 = res.shift
	var expect := ((Vector3(0.5, y, 0.5) - (mass.centre as Vector3)) * kg / (float(mass.kg) + kg))
	check(shift.distance_to(expect) < 0.001 and shift.y > 0.0, "TEST moves the centre of mass up toward the beams: %s" % [shift])
	check(d.test_line().contains("loose end") and d.test_line().contains("mm up"), "it says so: %s" % d.test_line())
	check("\n".join(d.info_lines()).contains("Test  Version A fails"), "the panel shows the test")
	d.add_beam(Vector3(-1, y, 2), Vector3(1, y, 2))
	check("\n".join(d.info_lines()).contains("changed since"), "an edit makes the test out of date")

	# R: version B, empty; drawn in on its own.
	check(d.key(TradesBus.KEY_ROTATE), "R shows the next version")
	check(d.version() == "B" and d.beams().is_empty(), "B starts empty")
	check(not d.undo(), "undo starts afresh on a switch")
	d.add_beam(Vector3(0, y, 0), Vector3(0, y, 3))
	check(d.beams().size() == 1 and bus.beam_design(ship, "A").size() == 3, "B's beam leaves A alone")
	# Shift+R: copy B into C.
	d.copy_to("C")
	check(d.version() == "C" and d.beams().size() == 1, "B copied into C and showing")
	d.delete_beam(int(d.beams()[0].id))
	check(d.beams().is_empty() and bus.beam_design(ship, "B").size() == 1, "deleting in C leaves B")
	d.key(TradesBus.KEY_ROTATE)
	check(d.version() == "A" and d.beams().size() == 3, "R wraps back to A")
	var counts := d.version_counts()
	check(int(counts.A) == 3 and int(counts.B) == 1 and int(counts.C) == 0, "each keeps its own: %s" % [counts])
	var info := "\n".join(d.info_lines())
	check(info.contains("[A] 3") and info.contains("B 1") and info.contains("C -"), "the panel lists them: %s" % info)
	await frames(1)
	var tab := rig.tool_node(&"tablet") as TradesDesignTablet
	check(tab.version == "A" and tab.readout_text().begins_with("BUILD A" if TradesDesignTablet.renamed() else "DESIGN A"), "the tablet shows the version: %s" % tab.readout_text())

	# A clash fails it; nothing to test.
	d.show_version("C")
	res = d.test()
	check(not bool(res.passed) and d.test_line().contains("no beams"), "an empty version has nothing to test")
	d.show_version("A")

	# The crew's events.
	check(d._validate(2, {"ship": ship, "show": "D"}) is String, "a version that doesn't exist is refused")
	check(d._validate(2, {"ship": ship, "show": "B"}) is Dictionary, "a switch is taken")
	check(d._validate(2, {"ship": ship, "version": "Q", "rows": []}) is String, "rows for a bad version are refused")
	var snap := d.get_net_snapshot()
	bus.reset_data()
	d.apply_net_snapshot(JSON.parse_string(JSON.stringify(snap)))
	check(bus.beam_design(ship, "A").size() == 3 and bus.beam_design(ship, "B").size() == 1, "a joiner's snapshot carries every version")

	# Flag off: R and H are left to the bay.
	Flags.set_flag("trades.beam_versions", false)
	check(not d.key(TradesBus.KEY_ROTATE) and not d.key(TradesBus.KEY_HELMET), "flag off: no versions or test keys")
	check(not "\n".join(d.info_lines()).contains("Version"), "flag off: the panel doesn't list versions")
	Flags.set_flag("trades.beam_versions", true)

	bus.reset_data()
	yard.queue_free()
	await frames(2)
	for flag: String in saved:
		Flags.set_flag(flag, saved[flag])


func _fake_yard() -> Node3D:
	var script := GDScript.new()
	script.source_code = FAKE_YARD
	script.reload()
	var n := Node3D.new()
	n.set_script(script)
	return n
