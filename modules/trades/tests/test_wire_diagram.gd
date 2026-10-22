extends ModuleTest
## Wiring on a diagram (beenster, 2026-10-21: stripping and crimping was too fiddly): a power
## or data plug on the ship opens its wiring diagram with the mouse free; drag each loom wire
## onto its pin, plug in, and the pins test. Fuel plugs stay one click.

const FAKE_YARD := """extends Node3D
var walker: CharacterBody3D
var walker_active := true
func set_walker_active(on: bool) -> void:
	walker_active = on
"""


func run_tests() -> void:
	_test_loom()
	var ship_bus := Modules.bus("ship_bay") as ShipBayBus
	var bus := Modules.bus("trades") as TradesBus
	var had := Flags.is_on("trades.wire_diagram")
	Flags.set_flag("trades.wire_diagram", true)
	ship_bus.load_ship("vs_kestrel")
	var yard := _fake_yard()
	add_child(yard)
	bus._on_shipyard_ready(yard)
	await frames(2)
	var rig: TradesBay = yard.get_node(TradesBus.YARD_RIG)
	var station := rig.ship_station()

	var i := _first(station, "power")
	check(i >= 0, "the Kestrel has a power plug")
	var f := station.points[i]
	_aim_at(rig, station, i)
	rig.set_tool(&"hands")
	check(station.aimed == i, "aimed at the power plug")
	check(station.uses_diagram(f), "power plugs are wired on the diagram")
	# Start with it out.
	if ship_bus.is_joint_tight(f.joint_id):
		station.back_out(&"hands")
		_run(station, TradesShipJoints.PLUG_S + 0.05)
	check(not ship_bus.is_joint_tight(f.joint_id), "the plug starts out")

	station.press(&"hands")
	var panel := station.wiring
	check(panel != null and panel.is_inside_tree(), "hands on the plug open its wiring diagram")
	check(station.tablet != null and panel.get_viewport() == station.tablet.viewport, "on the wiring tool's screen in front of you")
	check(rig.worker.look_locked, "the view holds still while it's open")
	await get_tree().create_timer(0.8).timeout
	check(station.tablet.is_open(), "it unfolds")
	var eye := rig.worker.camera.global_position
	var d := eye.distance_to(station.tablet.global_position)
	check(d > 0.3 and d < 0.7, "a screen's length in front of you (%.2f m)" % d)
	var px := station.tablet.ray_px(eye, (station.tablet.to_world(Vector2(300, 200)) - eye).normalized())
	check(px.distance_to(Vector2(300, 200)) < 2.0, "the mouse finds the picture where it is (%s)" % px)
	await get_tree().create_timer(0.3).timeout
	check(rig.worker.left_hand.out and rig.worker.right_hand.out, "both hands are on it")
	check(HudSlots.pointer_claimed(), "the diagram has the mouse")
	check(station.is_busy(), "and the station is busy while it's up")
	check(not ship_bus.is_joint_tight(f.joint_id), "opening it doesn't plug it in")
	check(panel._plug.disabled, "PLUG IN waits for every wire")

	# Drag one wire to the wrong pin, then put everything right through the board.
	var loom := panel.loom
	var board := panel.board
	board.drop(0, board.pin_at(1))
	check(loom.landed[0] == 1, "a wire dropped on a pin lands there")
	board.drop(1, board.pin_at(1))
	check(loom.landed[1] == 1 and loom.landed[0] == -1, "dropping another on that pin knocks the first off")
	board.drop(1, Vector2(5, 5))
	check(loom.landed[1] == -1, "dropping it off any pin lets it hang loose")
	for w in loom.pins.size():
		board.drop(w, board.pin_at(w))
	check(loom.all_landed() and loom.is_right() and not panel._plug.disabled, "every wire on its pin: ready to plug in")

	# Esc puts it away and keeps the wires.
	var esc := InputEventAction.new()
	esc.action = Keys.CANCEL
	esc.pressed = true
	var tablet := station.tablet
	tablet._input(esc)
	check(station.wiring == null and not HudSlots.pointer_claimed(), "Esc closes the diagram and frees the mouse")
	check(not rig.worker.look_locked, "and the view moves again")
	await get_tree().create_timer(0.8).timeout
	check(not is_instance_valid(tablet), "the wiring tool folds away")
	_aim_at(rig, station, i)  # no floor in this test yard: put the worker back where they stood
	station.press(&"hands")
	check(station.wiring != null and station.wiring.loom.is_right(), "opening it again, the wires are where you left them")

	# Plug in: tight, and Quality gets a good WIRE result.
	var got: Array = []
	var on_done := func(r: JointResult) -> void: got.append(r)
	bus.joint_completed.connect(on_done)
	station.wiring.plug_requested.emit()
	check(ship_bus.is_joint_tight(f.joint_id) and ship_bus.joint_quality(f.joint_id) > 0.95, "plugged in, full quality")
	var m: Dictionary = got[0].measurements if got.size() == 1 else {}
	check(got.size() == 1 and got[0].trade == &"WIRE", "Quality gets a WIRE result")
	check(float(m.get("continuity_ohm", -1.0)) > 0.0 and float(m.continuity_ohm) <= float(m.continuity_max_ohm)
			and bool(m.get("polarity_ok", false)) and not bool(m.get("miswired", true)), "it tests good")
	check((m.get("crimp_pull_n", []) as Array).size() == loom.pins.size() and bool(m.get("factory_terminated", false)),
			"the factory crimps are recorded per pin")
	check(station.wiring.status_text().contains("test good"), "the panel says the pins test good")
	station.close_wiring()

	# Pull it and rewire it wrong: in, but open on the bad pins and marked down.
	station.back_out(&"hands")
	_run(station, TradesShipJoints.PLUG_S + 0.05)
	check(not ship_bus.is_joint_tight(f.joint_id) and not loom.tested, "right click pulls the plug")
	station.press(&"hands")
	station.wiring.board.drop(2, station.wiring.board.pin_at(3))
	station.wiring.board.drop(3, station.wiring.board.pin_at(2))
	station.wiring.plug_requested.emit()
	m = got[1].measurements if got.size() == 2 else {}
	check(ship_bus.is_joint_tight(f.joint_id) and ship_bus.joint_quality(f.joint_id) < 0.5, "miswired: in, but marked down")
	check(float(m.get("continuity_ohm", 0.0)) < 0.0 and bool(m.get("miswired", false)) and int(m.get("wrong_pins", 0)) == 2,
			"two crossed wires read open")
	check(station.wiring.status_text().contains("3, 4"), "the panel names the bad pins")
	station.close_wiring()
	bus.joint_completed.disconnect(on_done)

	# Fuel plugs stay one click.
	var fuel := _first(station, "fuel")
	if fuel >= 0:
		check(not station.uses_diagram(station.points[fuel]), "fuel plugs don't open a diagram")

	# With the flag off, the power plug is one click again.
	Flags.set_flag("trades.wire_diagram", false)
	check(not station.uses_diagram(f), "flag off: no diagram")
	Flags.set_flag("trades.wire_diagram", had)
	yard.queue_free()
	await frames(1)


func _test_loom() -> void:
	var a := TradesWireLoom.new("power", "slot/p1")
	var b := TradesWireLoom.new("power", "slot/p1")
	check(a.pins.size() == 6 and a.order == b.order, "a power plug has 6 pins, its tails in the same order every time")
	check(a.order != PackedInt32Array(range(6)) or TradesWireLoom.new("power", "other/p1").order != a.order,
			"the tails are shuffled per plug")
	a.land(0, 5)
	check(a.is_short() and a.measurements().insulation_mohm == 0.0, "+28 V on the chassis pin shorts")
	a.clear()
	for w in 6:
		a.land(w, w)
	a.land(0, 1)
	a.land(1, 0)
	var m := a.measurements()
	check(not m.polarity_ok and m.continuity_ohm < 0.0, "supply wires swapped: reversed and open")
	check(TradesWireLoom.new("data", "x").pins.size() == 5 and not TradesWireLoom.supports("fuel"), "data has 5 pins, fuel none")


func _first(station: TradesShipJoints, spec: String) -> int:
	for i in station.points.size():
		if station.points[i].kind == "connector" and station.points[i].spec == spec:
			return i
	return -1


func _run(station: TradesShipJoints, seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		station.update(minf(0.05, left))
		left -= 0.05


func _aim_at(rig: TradesBay, station: TradesShipJoints, i: int) -> void:
	var at := station.points_world[i]
	var n := station.ship_xform.basis * station.points[i].normal
	var out := Vector3(n.x, 0.0, n.z)
	if out.length() < 0.2:
		out = Vector3(at.x, 0.0, at.z) - Vector3(station.ship_xform.origin.x, 0.0, station.ship_xform.origin.z)
	var feet := at + out.normalized() * 0.9
	feet.y = 0.0
	rig.worker.global_position = feet
	rig.worker.face(at)
	station.update(0.0)


func _fake_yard() -> Node3D:
	var script := GDScript.new()
	script.source_code = FAKE_YARD
	script.reload()
	var yard := Node3D.new()
	yard.set_script(script)
	var walker := CharacterBody3D.new()
	walker.position = Vector3(3, 0, 6)
	yard.set("walker", walker)
	yard.add_child(walker)
	return yard
