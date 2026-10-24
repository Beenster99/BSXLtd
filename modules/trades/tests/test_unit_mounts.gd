extends ModuleTest
## Component Upgrades U1: a unit on the upgrade rig opens up for its add-ons. The cover's
## bolts and tack welds come out and it swings open; F puts each add-on on its seat (three at
## most: core, emitter horns, control board), whose bolts, seams and plugs are then worked
## like any other joint; put a cover joint back and the inside closes off. Quality hears every
## joint and change through TradesBus.

const FAKE_YARD := """extends Node3D
var walker: CharacterBody3D
var walker_active := true
func set_walker_active(on: bool) -> void:
	walker_active = on
"""
const FLAGS := ["trades.test_stand", "trades.unit_mounts", "trades.near_rings"]
const RIG := "rig_emitter"
const AT := Vector3(30, 0.95, 30)

var _joint_events: Array = []
var _unit_events: Array = []


func run_tests() -> void:
	_patterns()
	var ship_bus := Modules.bus("ship_bay") as ShipBayBus
	var bus := Modules.bus("trades") as TradesBus
	var saved := {}
	for flag: String in FLAGS:
		saved[flag] = Flags.is_on(flag)
		Flags.set_flag(flag, true)
	ship_bus.load_ship("vs_kestrel")
	var yard := _fake_yard()
	add_child(yard)
	bus._on_shipyard_ready(yard)
	await frames(2)
	var rig: TradesBay = yard.get_node(TradesBus.YARD_RIG)
	var station := rig.ship_station()
	bus.unit_joint_changed.connect(func(r: String, id: String, made: bool, q: float) -> void: _joint_events.append([r, id, made, q]))
	bus.unit_changed.connect(func(r: String, s: Dictionary) -> void: _unit_events.append([r, s]))

	# A coil goes on the rig (as Ship and Bay's rig_changed says): closed, its cover's joints in.
	station.rigs[RIG] = Transform3D(Basis(), AT)
	station.add_unit(RIG, "attractor_coil_1", 3, Transform3D(Basis(), AT))
	await frames(1)
	var unit := station.unit
	check(unit != null and unit.unit_id == "attractor_coil_1", "the coil is on the rig")
	check(unit.seats.size() == 3, "three seats on a tier 3 coil: %s" % [unit.seats])
	var mine := _unit_points(station)
	check(mine.size() == 6 and mine.all(func(i: int) -> bool: return station.points[i].joint_id.contains("_cover/")),
			"only the cover's 6 joints to work while it's shut (%d)" % mine.size())
	check(mine.all(func(i: int) -> bool: return station.is_tight(station.points[i])), "all of them made")
	check(mine.all(func(i: int) -> bool: return TradesShipJoints.is_practice(station.points[i])), "kept by Tools, not Ship and Bay")
	var cover_bolt := mine.filter(func(i: int) -> bool: return station.points[i].kind == "bolt")[0] as int
	check(station.points_world[cover_bolt].distance_to(AT + unit.joints[0].position) < 0.001
			or mine.any(func(i: int) -> bool: return station.points_world[i].y > AT.y + 0.4), "the cover's joints sit on the unit's rim, in the world")
	check(bus.unit_state(RIG).get("open") == false and (bus.unit_state(RIG).get("fitted") as Dictionary).is_empty(), "Quality reads it closed, empty")

	# Aim at a cover bolt: it's picked like a ship bolt.
	_aim(rig, station, station.points_world[cover_bolt])
	check(station.aimed == cover_bolt, "a cover bolt is picked by the aim (%d, wanted %d)" % [station.aimed, cover_bolt])
	check(not station.key(Keys.INTERACT), "F does nothing while the cover is on")

	# Take the cover's joints out: it opens and the seats show.
	for i in mine:
		station._note_removed(station.points[i])
	await frames(1)
	check(unit.is_open(), "every cover joint out: the cover opens")
	check(bus.unit_state(RIG).get("open") == true, "Quality reads it open")
	unit._show(1.0)
	check(unit._cover.rotation.x < -1.0, "the lid swings up (%.2f)" % unit._cover.rotation.x)

	# F on each seat fits its add-on; its joints join the work, not made yet.
	for seat: String in unit.seats:
		_aim(rig, station, unit.global_transform * unit.seat_centre(seat))
		station.aimed = -1
		var tips := " ".join(rig.context_tips())
		check(tips.contains("fit the"), "pointing at the %s seat, F's tip says fit it: %s" % [seat, tips])
		check(station.key(Keys.INTERACT), "F fits the %s" % seat)
		check(unit.is_fitted(seat), "the %s is in" % seat)
	await frames(1)
	mine = _unit_points(station)
	var kinds := {}
	for i in mine:
		var f := station.points[i]
		var mount := unit.mount_of(f.joint_id)
		if mount != "cover":
			kinds[mount + ":" + f.kind] = int(kinds.get(mount + ":" + f.kind, 0)) + 1
			check(not station.is_tight(f), "%s starts undone" % f.joint_id)
	check(kinds == {"core:bolt": 6, "emitter:weld": 2, "board:connector": 2},
			"the core's 6 bolts, the horns' 2 seams, the board's 2 plugs: %s" % [kinds])
	check(_unit_events.size() >= 4 and bus.unit_state(RIG).get("fitted") == {"core": "quantum_core_3", "emitter": "field_emitter_3", "board": "control_board"},
			"Quality heard each add-on go in, by part: %s" % [bus.unit_state(RIG).get("fitted")])

	# Nowhere for a fourth: every seat is taken, and F on a fitted one lifts it, never adds.
	check(unit.seats.size() == 3 and unit.fitted().size() == 3, "three in, no seat left")
	_aim(rig, station, unit.global_transform * unit.seat_centre("board"))
	station.aimed = -1
	station.key(Keys.INTERACT)
	check(not unit.is_fitted("board") and unit.fitted().size() == 2, "F on a loose add-on lifts it back out")
	station.key(Keys.INTERACT)
	check(unit.is_fitted("board"), "and F puts it back")
	await frames(1)

	# Make a core bolt: Quality hears it with its quality; the core can't come out now.
	mine = _unit_points(station)
	var core_bolt := mine.filter(func(i: int) -> bool: return unit.mount_of(station.points[i].joint_id) == "core")[0] as int
	var core_id := station.points[core_bolt].joint_id
	_joint_events.clear()
	station._made(station.points[core_bolt], 0.8)
	check(station.is_tight(station.points[core_bolt]), "the core bolt is in")
	check(_joint_events.size() == 1 and _joint_events[0] == [RIG, core_id, true, 0.8], "Quality got the joint and its quality: %s" % [_joint_events])
	check(is_equal_approx(float((bus.unit_state(RIG).get("joints") as Dictionary).get(core_id)), 0.8), "and unit_state has it")
	_aim(rig, station, unit.global_transform * unit.seat_centre("core"))
	station.aimed = -1
	station.key(Keys.INTERACT)
	check(unit.is_fitted("core"), "a core with a bolt in stays put")
	check(rig._hint_label.text.contains("Undo"), "and the hint says to undo it first: %s" % rig._hint_label.text)

	# A crewmate's change arrives: the same.
	station.set_practice(unit.slot_of("emitter") + "/fitted", false)
	await frames(1)
	check(not unit.is_fitted("emitter") and not _unit_points(station).any(func(i: int) -> bool: return unit.mount_of(station.points[i].joint_id) == "emitter"),
			"a crewmate lifting the horns out takes their seams off the work")

	# Put one cover bolt back: the cover shuts and the inside is out of reach.
	var cover := unit.mount_joints("cover")[0]
	var ci := -1
	for i in station.points.size():
		if station.points[i].joint_id == cover.joint_id:
			ci = i
	station._made(station.points[ci], 1.0)
	await frames(1)
	check(not unit.is_open(), "a cover bolt in: it's shut")
	check(_unit_points(station).all(func(i: int) -> bool: return unit.mount_of(station.points[i].joint_id) == "cover"), "only the cover's joints to work again")
	check(unit.is_fitted("core") and unit.made(core_id), "what was done inside stays")

	# Off the rig: the unit and its joints go, and Quality hears it's gone.
	rig._on_rig_changed(RIG, {"unit": ""})
	await frames(1)
	check(station.unit == null and _unit_points(station).is_empty(), "off the rig, nothing left to work")
	check(bus.unit_state(RIG).is_empty(), "unit_state is empty")

	# A tier 1 coil has only the core seat.
	station.add_unit(RIG, "attractor_coil_1", 1, Transform3D(Basis(), AT))
	check(station.unit.seats.size() == 1 and station.unit.seats[0] == "core", "tier 1: the core seat only (%s)" % [station.unit.seats])
	station.remove_unit()
	var bare := station.add_unit(RIG, "attractor_coil_1", 3, Transform3D(Basis(), AT), true)
	check(bare.get_node_or_null("Body") == null and bare.mount_joints("cover").size() == 6,
			"when the rig draws the case, ours draws none but keeps the cover's joints")
	station.remove_unit()

	await _rig_path(ship_bus, rig, station)
	await _on_the_model(bus, rig, station)

	yard.queue_free()
	await frames(1)
	for flag: String in saved:
		Flags.set_flag(flag, saved[flag])


## Ship and Bay's rig: a unit mounted there comes to Tools, set in the rig's housing while the
## rig has no model of it (this fake yard has no rig node), and goes when it's taken off.
func _rig_path(ship_bus: ShipBayBus, rig: TradesBay, station: TradesShipJoints) -> void:
	ship_bus.rig_mount(RIG, "attractor_coil_2")
	await frames(2)
	check(station.unit != null and station.unit.unit_id == "attractor_coil_2" and station.unit.bare,
			"a coil mounted on Ship and Bay's rig comes to Tools")
	check(station.points.any(func(f: FastenerPoint) -> bool: return f.joint_id == "rig_emitter/b1"),
			"with the rig's hold-down bolts to work")
	ship_bus.rig_unmount(RIG)
	await frames(2)
	check(station.unit == null, "taken off the rig, it's gone")


## On Shared Components' coil (what the rig builds): its cover's bolts and tacks, add-ons fitted
## with fit_addon and taken off again, each joint on the model only while it's made.
func _on_the_model(bus: TradesBus, rig: TradesBay, station: TradesShipJoints) -> void:
	var body := RigidBody3D.new()
	body.freeze = true
	add_child(body)
	body.global_position = AT
	var kit := ShipKit.new(body)
	kit.model = PartModel.new(body, true)
	var rec := UpgradeUnits.attractor_coil(kit, 3, Transform3D(Basis(), Vector3(0, 0.15, 0)), "rig:emitter")
	rec["kit"] = kit
	var model := kit.model
	var before := model.connections.size()
	var unit := station.add_unit(RIG, "attractor_coil_3", 3, body.global_transform, true, rec)
	await frames(1)
	check(unit.model == model and unit.seats.size() == 3, "on their model, three mounts: %s" % [unit.seats])
	check(model.connections.size() == before, "the trial fits leave nothing behind (%d, was %d)" % [model.connections.size(), before])
	var cover := unit.mount_joints("cover")
	check(cover.filter(func(f: FastenerPoint) -> bool: return f.kind == "bolt").size() == 4
			and cover.filter(func(f: FastenerPoint) -> bool: return f.kind == "weld").size() == 2, "the cover's 4 bolts and 2 tacks are theirs")
	check(unit.mount_joints("core").size() == 2 and unit.mount_joints("emitter").size() == 1 and unit.mount_joints("board").size() == 1,
			"the core's 2 clamps, the array's seam, the board's plug")
	var c0 := (rec["bolts"] as Array)[0] as ConnectionData
	check(cover[0].position.is_equal_approx(c0.local_position), "where their model has them")
	for f in cover:
		station._note_removed(_point(station, f.joint_id))
	await frames(1)
	var lid := rec["cover"] as PartData
	check(unit.is_open() and model.connections.size() == before - 6, "cover joints out: off the model too (%d)" % model.connections.size())
	check(not lid.local_transform.is_equal_approx(unit._cover_closed), "and the cover lifts off")
	for seat: String in unit.seats:
		station._set_seat(unit.slot_of(seat) + "/fitted", true)
	await frames(1)
	var names := model.parts.values().map(func(p: PartData) -> String: return p.part_name)
	check(names.has("QuantumCore") and names.has("FieldEmitter") and names.has("ControlBoard"), "their add-ons go in: %s" % [names])
	check(bus.unit_state(RIG).get("fitted") == {"core": "quantum_core_3", "emitter": "field_emitter_3", "board": "control_board"},
			"Quality reads the part ids: %s" % [bus.unit_state(RIG).get("fitted")])
	check(model.connections.size() == before - 6, "their joints start undone")
	var clamp := unit.mount_joints("core")[0]
	station._made(_point(station, clamp.joint_id), 0.9)
	check(model.connections.size() == before - 5, "a clamp bolt made is on the model")
	station._note_removed(_point(station, clamp.joint_id))
	station._set_seat(unit.slot_of("board") + "/fitted", false)
	names = model.parts.values().map(func(p: PartData) -> String: return p.part_name)
	check(not names.has("ControlBoard") and model.connections.size() == before - 6, "the board lifts back out")
	station._made(_point(station, cover[0].joint_id), 1.0)
	check(lid.local_transform.is_equal_approx(unit._cover_closed) and model.connections.size() == before - 5, "a cover bolt in: the cover's back on")
	station.remove_unit()
	body.queue_free()


func _point(station: TradesShipJoints, joint_id: String) -> FastenerPoint:
	for f in station.points:
		if f.joint_id == joint_id:
			return f
	return null


## The mount patterns on their own: what holds each add-on, ids unique, in mount space.
func _patterns() -> void:
	var at := Transform3D(Basis(), Vector3(1, 2, 3))
	var cover := TradesMountPatterns.pattern("cover", "s", at, Vector3(1.2, 0.02, 0.7))
	check(cover.filter(func(f: FastenerPoint) -> bool: return f.kind == "bolt" and f.spec == "M10").size() == 4, "cover: 4 M10 bolts")
	check(cover.filter(func(f: FastenerPoint) -> bool: return f.kind == "weld" and f.seam_size.x > 0.0).size() == 2, "cover: 2 tack welds")
	var core := TradesMountPatterns.pattern("core", "t", at, Vector3(0.34, 0.3, 0.34))
	check(core.size() == 6 and core.all(func(f: FastenerPoint) -> bool: return f.spec == "M12" and absf(f.position.y - 2.0) < 0.001), "core: 6 M12 bolts on its seat")
	var board := TradesMountPatterns.pattern("board", "s", at, Vector3(0.2, 0.03, 0.16))
	check(board.map(func(f: FastenerPoint) -> String: return f.spec) == ["power", "data"], "board: a power and a data plug")
	var ids := {}
	for f in cover + core:
		ids[f.joint_id] = true
	check(ids.size() == cover.size() + core.size(), "joint ids are unique")
	check(TradesMountPatterns.pattern("nonsense", "s", at, Vector3.ONE).is_empty(), "an unknown mount has no joints")


func _unit_points(station: TradesShipJoints) -> Array[int]:
	var out: Array[int] = []
	for i in station.points.size():
		if TradesShipJoints.is_unit(station.points[i]):
			out.append(i)
	return out


func _aim(rig: TradesBay, station: TradesShipJoints, at: Vector3) -> void:
	rig.worker.global_position = Vector3(at.x, 0.0, at.z + 0.7)
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
	floor_shape.position = Vector3(0, -0.1, 0)
	floor_body.add_child(floor_shape)
	yard.add_child(floor_body)
	return yard
