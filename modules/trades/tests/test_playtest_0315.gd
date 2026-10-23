extends ModuleTest
## beenster's 0.3.15 playtest: the hint stays up while you look at what it's about, the power
## wrench works on left click only with X for fasten or undo, the welder's sparks and molten
## metal bounce about the floor for about eight seconds (0.3.16), a weld starts from an end of its seam
## with no ring in its middle and the bead shows under the shield, the welder is carried clear
## of the view, tools and the hand on them are drawn up out on the work, and the wiring tool's
## hand keeps off the screen and the tool packs away once plugged in.

const FAKE_YARD := """extends Node3D
var walker: CharacterBody3D
var walker_active := true
func set_walker_active(on: bool) -> void:
	walker_active = on
"""
const FLAGS := ["trades.test_stand", "trades.power_wrench", "trades.wire_diagram", "trades.trace_weld",
		"trades.weld_helmet", "trades.hint_stays", "trades.wrench_left_only", "trades.molten",
		"trades.weld_from_end", "trades.welder_clear", "trades.reach_scale", "trades.wiring_tidy",
		"trades.tool_display"]


func run_tests() -> void:
	var ship_bus := Modules.bus("ship_bay") as ShipBayBus
	var bus := Modules.bus("trades") as TradesBus
	var saved := {}
	for flag: String in FLAGS:
		saved[flag] = Flags.is_on(flag)
		Flags.set_flag(flag, true)
	# The shield on the arc alone (test_playtest_0316 has its key).
	saved["trades.helmet_toggle"] = Flags.is_on("trades.helmet_toggle")
	Flags.set_flag("trades.helmet_toggle", false)
	ship_bus.load_ship("vs_kestrel")
	var yard := _fake_yard()
	add_child(yard)
	bus._on_shipyard_ready(yard)
	await frames(2)
	var rig: TradesBay = yard.get_node(TradesBus.YARD_RIG)
	var station := rig.ship_station()

	# The hint stays while you look at the same thing, and goes when you look away.
	var b := _first(station, "bolt", false)
	_aim_at(rig, station, b)
	rig.set_tool(&"torque_wrench")
	rig.hint("Already tight.")
	rig._hint_at -= int(TradesBay.HINT_S * 1000.0) + 500
	check(rig.hint_showing(), "past its time the hint stays while you look at the same bolt")
	rig.worker.face(rig.worker.global_position + Vector3(0, 30, 0))
	station.update(0.0)
	check(not rig.hint_showing(), "and goes once you look away")

	# The power wrench: right click does nothing but say where it works; X and left click undo.
	_aim_at(rig, station, b)
	var wrench := rig.tool_node(&"torque_wrench") as TradesPowerWrench
	wrench.undo = false
	station._stall_at = -1.0
	station.press(&"torque_wrench")
	station._stall_at = -1.0
	_run(rig, station, TradesShipJoints.RUN_S * 1.2)
	station.release()
	check(station.is_tight(station.points[b]), "left click runs the bolt in")
	station.back_out(&"torque_wrench")
	check(not station.is_busy() and rig._hint_label.text.contains("left click"), "right click doesn't undo it: %s" % rig._hint_label.text)
	rig._on_action(TradesBus.KEY_MODE)
	check(wrench.undo, "X switches the wrench to undo")
	station.press(&"torque_wrench")
	station._stall_at = -1.0
	_run(rig, station, TradesShipJoints.RUN_S * 1.2)
	station.release()
	check(not station.is_tight(station.points[b]), "and left click takes it out")
	wrench.undo = false

	# A weld seam: no ring in its middle, a small one at the end, and the arc only strikes there.
	var w := _first(station, "weld", false)
	_aim_at(rig, station, w)
	rig.set_tool(&"welder")
	var torch := rig.tool_node(&"welder") as TradesWeldTorch
	torch.unweld = false
	var f := station.points[w]
	var along := station.ship_xform.basis * f.seam_up
	var at := station.points_world[w]
	station.update(0.0)
	check(station._marker.global_position.distance_to(at) > f.seam_size.x * 0.4, "the ring sits at an end of the seam, not its middle")
	station.press(&"welder")
	check(not station.is_busy(), "mid-seam the arc won't strike")
	rig.worker.face(at - along * f.seam_size.x * 0.5)
	station.update(0.0)
	station.press(&"welder")
	check(station.is_busy(), "at the end it strikes")
	_run(rig, station, 0.2)
	check(not station._marker.visible, "no ring while the arc runs")
	check(torch.display_hidden(), "the welder's display folds away under the shield")
	for k in 21:
		rig.worker.face(at + along * (f.seam_size.x * (k / 40.0 - 0.5)))
		station.update(0.05)
		rig.update_helmet(0.05)
	station.release()
	var half := station.trace_progress(f)
	check(half > 0.3 and half < 0.8, "half the seam traced (%.2f)" % half)
	rig.worker.face(at + along * f.seam_size.x * 0.3)
	station.update(0.0)
	station.press(&"welder")
	check(not station.is_busy(), "you can't pick it up again away from the bead's end")
	rig.worker.face(at + along * (f.seam_size.x * (half - 0.5)))
	station.update(0.0)
	station.press(&"welder")
	check(station.is_busy(), "but you can from where the bead ends")
	for k in range(20, 41):
		rig.worker.face(at + along * (f.seam_size.x * (k / 40.0 - 0.5)))
		station.update(0.05)
		rig.update_helmet(0.05)
	check(station.is_tight(f), "traced to the other end: welded")
	_run(rig, station, TradesShipJoints.BEAD_COOL_S + 0.5)
	check(station.hot_beads() == 0 and station.beads() > 0, "the bead cools but stays to see (%d)" % station.beads())
	check(rig.sparks.dim == 0.0, "shield up: the sparks light the place again")

	# The welder's shower lasts about eight seconds, and comes to rest on the floor.
	var sparks := rig.sparks
	var floor_at := rig.worker.global_position + Vector3(0, 1.0, -0.5)
	var before := sparks.count()
	for k in 10:
		sparks.emit_weld(floor_at, Vector3.UP, TradesShipJoints.weld_sparks(false), 3.2, 0.7)
	var step := 1.0 / 60.0
	var t := 0.0
	while t < 6.5:
		sparks._physics_process(step)
		t += step
	check(sparks.count() > before, "six and a half seconds on, sparks are still about (%d)" % sparks.count())
	check(sparks.resting() > 0, "some lie on the floor (%d)" % sparks.resting())
	while t < 8.7:
		sparks._physics_process(step)
		t += step
	check(sparks.count() <= before, "by about eight seconds they're gone (%d)" % sparks.count())

	# The welder is carried low and pointing forward, not stood up in the view.
	torch.lit = false
	var carried := torch.carried(rig.worker.right_hand.palm())
	var nozzle := rig.worker.camera.global_transform.affine_inverse() * carried.origin
	var neck := rig.worker.camera.global_transform.affine_inverse() * (carried * Vector3(0, 0.08, 0))
	check(nozzle.z < neck.z, "in your hand the nozzle points away from you")

	# Out on the work the tool and your hand are drawn up; in your hand they're true size.
	var b2 := _first(station, "bolt", false)
	_aim_at(rig, station, b2)
	rig.worker.global_position += (rig.worker.global_position - station.points_world[b2]).normalized() * Vector3(0.6, 0, 0.6)
	rig.worker.face(station.points_world[b2])
	station.update(0.0)
	rig.set_tool(&"torque_wrench")
	station._stall_at = -1.0
	station.press(&"torque_wrench")
	station._stall_at = -1.0
	station.update(0.05)
	rig._scale_reach(0.0)
	check(rig.reach_scale > 1.1 and rig.worker.right_hand.size == rig.reach_scale,
			"at arm's length the wrench and hand are drawn up (%.2f)" % rig.reach_scale)
	var t_wrench := rig.tool_node(&"torque_wrench")
	check(t_wrench.global_transform.basis.get_scale().x > 1.1, "the wrench itself is bigger")
	station.release()
	station._stop()
	rig._placed.clear()
	rig._scale_reach(0.0)
	check(rig.reach_scale == 1.0, "back in your hand: true size")

	# The wiring tool: the hand waits off the screen till it carries a wire, and the tool packs
	# away once plugged in.
	var p := -1
	for i in station.points.size():
		if TradesShipJoints.is_practice(station.points[i]) and station.uses_diagram(station.points[i]) and not station.is_tight(station.points[i]):
			p = i
			break
	check(p >= 0, "a plug on the stand")
	if p >= 0:
		_aim_at(rig, station, p)
		rig.set_tool(&"hands")
		var panel := station.open_wiring(p)
		var tablet := station.tablet
		tablet.opened = 1.0
		tablet._hands()
		var hand := rig.worker.left_hand
		check(hand.target.distance_to(tablet.global_position) > TradesWiringTablet.SIZE_M.x * 0.5 and hand.see_through == 0.0,
				"not carrying a wire, the hand waits off the screen")
		panel.board.dragging = 0
		tablet._hands()
		check(hand.see_through > 0.0, "carrying one, it comes on and you see through it")
		panel.board.dragging = -1
		for k in panel.loom.pins.size():
			panel.loom.land(k, k)
		station._plug_wiring()
		check(station.is_tight(station.points[p]), "plugged in")
		await get_tree().create_timer(TradesShipJoints.PACK_AWAY_S + 0.3).timeout
		check(station.wiring == null, "and the wiring tool packs itself away")

	for flag: String in saved:
		Flags.set_flag(flag, saved[flag])


func _run(rig: TradesBay, station: TradesShipJoints, seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		station.update(minf(0.05, left))
		rig.update_helmet(minf(0.05, left))
		left -= 0.05


func _first(station: TradesShipJoints, kind: String, made: bool) -> int:
	for i in station.points.size():
		var f := station.points[i]
		if TradesShipJoints.is_practice(f) and f.kind == kind and station.is_tight(f) == made:
			return i
	return -1


func _aim_at(rig: TradesBay, station: TradesShipJoints, i: int) -> void:
	var at := station.points_world[i]
	var n := (station.ship_xform.basis * station.points[i].normal).normalized()
	var feet := at + Vector3(n.x, 0.0, n.z).normalized() * 0.8
	feet.y = station.test_stand.global_position.y
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
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 0.2, 80)
	floor_shape.shape = box
	floor_shape.position.y = -0.1
	floor_body.add_child(floor_shape)
	yard.add_child(floor_body)
	return yard
