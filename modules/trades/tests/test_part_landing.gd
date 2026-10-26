extends ModuleTest
## Loose parts land like the real thing (beenster, 26 Oct: "When objects hit the floor that I
## have removed they should clang like in real life. Objects removed from a salvage seem to
## hover slightly above ground. These same objects should stack on top of each other ...
## Objects should stack on these trolleys."):
## - trades.part_landing: a part's collision is the hull of its look, so a tilted plate lies
##   flat on the floor instead of on its slot box's face in the air; landings clang, louder
##   for harder hits.
## - trades.parts_on_decks: beamed onto a trolley, the part stays itself on the deck, stacks
##   on the parts already there, rides with the deck, and goes when Ship and Bay releases it.
## Ship and Bay's trolley calls are played by a stand-in with a deck body of our own.

const FAKE_API := """extends RefCounted
var deck: Node3D
var noted := {}
func beam_to_trolley(slot_id: String, component: String, condition: float, from: Vector3) -> String:
	return "m"
func cancel_beam(slot_id: String) -> void:
	pass
func trolley_deck_position(id: String) -> Variant:
	return deck.global_position if deck else null
func fitted_condition(slot_id: String) -> float:
	return 1.0
func note_loose(slot_id: String, component: String, condition: float, body: Node3D) -> void:
	noted[slot_id] = body
func forget_loose(slot_id: String) -> void:
	noted.erase(slot_id)
"""
## A plate whose slot box is a fat AABB round the tilted plate (it used to land 0.5 m up).
const PLATE := "plate_cockpit_wall_e1"
const ENGINES := ["eng_port", "eng_stbd"]


func run_tests() -> void:
	var saved := {}
	for flag: String in ["trades.shipyard", "trades.tractor", "ship_bay.clean_up", "trades.part_landing", "trades.parts_on_decks"]:
		saved[flag] = Flags.is_on(flag)
		Flags.set_flag(flag, true)
	var ship_bus := Modules.bus("ship_bay") as ShipBayBus
	var trades := Modules.bus("trades") as TradesBus
	ship_bus.reset_data()
	var yard := (load(Router.scene_path(ShipBayBus.SHIPYARD_SCENE)) as PackedScene).instantiate() as Node3D
	add_child(yard)
	await frames(3)
	var rig: TradesBay = yard.get_node_or_null(TradesBus.YARD_RIG)
	check(rig != null and ship_bus.get_slot(PLATE) != null, "the yard is up with the ship's plate")
	if rig == null or ship_bus.get_slot(PLATE) == null:
		yard.queue_free()
		return
	var beam := rig.ship_station().tractor
	var api: Object = _make(FAKE_API, RefCounted.new())
	beam.trolley_api = api

	# Off the ship, the plate falls and lies flat on the floor: no gap under it.
	for f in ship_bus.get_fasteners(PLATE):
		ship_bus.note_joint_removed(f.joint_id)
	await frames(2)
	var plate: TradesLoosePart = beam.loose.get(PLATE)
	check(plate != null and plate.get_child(0) is CollisionShape3D, "the plate is loose")
	if plate == null:
		yard.queue_free()
		return
	var shape := (plate.get_child(0) as CollisionShape3D).shape
	check(shape is ConvexPolygonShape3D, "its collision is the hull of its look, not its slot's box")
	# Dropped from 1.5 m onto open yard floor beside the ship, turned as it came off.
	await _rest(plate, 6.0)
	plate.global_position = Vector3(plate.global_position.x + 9.0, 1.5 + plate.depth_below(), plate.global_position.z)
	plate.drop()
	await _rest(plate, 6.0)
	var gap := _gap_under(plate)
	check(absf(gap) < 0.03, "it lies on the floor, not above it (gap %.3f m)" % gap)
	check(plate.clangs > 0, "it clanged when it hit (%d)" % plate.clangs)

	# Harder hits are louder; a gentle touch is silent.
	var before := plate.clangs
	plate._clang_s = 1.0
	plate.clang(0.3)
	check(plate.clangs == before, "a gentle touch makes no sound")
	plate.clang(1.2)
	var soft := float(plate.last_clang[1])
	plate._clang_s = 1.0
	plate.clang(5.0)
	var loud := float(plate.last_clang[1])
	check(loud > soft + 6.0, "a hard hit is louder (%.0f dB vs %.0f dB)" % [loud, soft])
	plate.clang(5.0)
	check(plate.clangs == before + 2, "contacts chattering as it settles don't clang again at once")
	var p3 := plate.find_children("*", "AudioStreamPlayer3D", false, false)
	check(not p3.is_empty() and (p3[0] as AudioStreamPlayer3D).bus == Sfx.bus(), "the clang plays in 3D on the Effects bus")

	# A trolley deck of our own: an open plate, out in the yard.
	var deck := AnimatableBody3D.new()
	deck.name = "Deck"
	deck.sync_to_physics = false
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 0.12, 3.0)
	col.shape = box
	col.position.y = -0.06
	deck.add_child(col)
	yard.add_child(deck)
	deck.global_position = plate.global_position + Vector3(6, 0.8, 0)
	api.set("deck", deck)

	# Both engines come off; each is beamed onto the deck as its own crate.
	var engines: Array[TradesLoosePart] = []
	var landed := []
	trades.part_on_deck.connect(func(id: String, body: Node3D, on: Node3D) -> void: landed.append([id, body, on]))
	for i in ENGINES.size():
		for f in ship_bus.get_fasteners(ENGINES[i]):
			ship_bus.note_joint_removed(f.joint_id)
		await frames(2)
		var e: TradesLoosePart = beam.loose.get(ENGINES[i])
		engines.append(e)
		beam.to_trolley[ENGINES[i]] = "m"
		beam._on_part_beamed("crate_%d" % i, "m", e.component, ENGINES[i])
		check(not beam.loose.has(ENGINES[i]) and beam.on_deck.get("crate_%d" % i) == e and trades.deck_part("crate_%d" % i) == e,
				"%s stays as itself for its crate, no longer loose" % ENGINES[i])
		await _ride(e, 6.0)
	var a := engines[0]
	var b := engines[1]
	check(a.riding == deck, "the first engine rests on the deck and rides it")
	check(b.riding == deck, "the second rests on it too (through the first)")
	var a_box := a.global_transform * a.outline
	check(b.global_position.y > a.global_position.y + a_box.size.y * 0.5,
			"the second stacks on top of the first (%.2f over %.2f)" % [b.global_position.y, a.global_position.y])
	check(landed.size() == 2 and landed[0][2] == deck, "Ship and Bay hears each landed on the deck (%d)" % landed.size())

	# The trolley drives off: the stack goes with it.
	var a_from := a.global_position
	var b_from := b.global_position
	deck.global_position += Vector3(2.5, 0, -1.0)
	await frames(3)
	check(a.global_position.distance_to(a_from + Vector3(2.5, 0, -1.0)) < 0.01 and
			b.global_position.distance_to(b_from + Vector3(2.5, 0, -1.0)) < 0.01, "the stack rides with the deck")
	check(beam.aimed_part() != a and not beam.loose.values().has(a), "the beam can't take them off the deck")

	# The crates leave the trolley (Ship and Bay's deck_part_left, or a release): the parts go.
	trades.release_deck_part("crate_0")
	beam._on_deck_part_left("crate_1", "m")
	await frames(2)
	check(not is_instance_valid(a) and not is_instance_valid(b) and beam.on_deck.is_empty(), "released crates take their parts")
	check(trades.deck_part("crate_0") == null, "and nothing is listed on the deck")

	yard.queue_free()
	await frames(1)
	ship_bus.reset_data()
	for flag: String in saved:
		Flags.set_flag(flag, saved[flag])


## Waits until the part is still (or `limit` seconds).
func _rest(part: TradesLoosePart, limit: float) -> void:
	var t := 0.0
	var still := 0.0
	while t < limit and still < 0.4:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		still = still + get_physics_process_delta_time() if part.linear_velocity.length() < 0.03 else 0.0


func _ride(part: TradesLoosePart, limit: float) -> void:
	var t := 0.0
	while t < limit and part.riding == null:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()


## The gap between the part's lowest point and the ground under its middle (m; a hair
## under 0 is resting contact).
func _gap_under(part: TradesLoosePart) -> float:
	var space := part.get_world_3d().direct_space_state
	var bottom := part.global_position.y - part.depth_below()
	var at := part.centre()
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, Vector3(at.x, bottom - 2.0, at.z))
	q.exclude = [part.get_rid()]
	var hit := space.intersect_ray(q)
	return bottom - float((hit.position as Vector3).y) if not hit.is_empty() else 9.0


func _make(source: String, obj: Object) -> Object:
	var script := GDScript.new()
	script.source_code = source
	script.reload()
	obj.set_script(script)
	return obj
